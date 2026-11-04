"""Offline checks for released parameters, entrypoints and static-summary semantics."""

import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

import pandas as pd

import main as detector_cli
from experiments import analyze_results
from pmdetector.llm import analyze_taint_paths, llm_service, multi_agents, narrative_generator


class TemperatureTests(unittest.TestCase):
    def test_openai_sdk_and_http_send_zero(self):
        client = MagicMock()
        client.chat.completions.create.return_value = SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=" narrative "))])
        with patch("openai.OpenAI", return_value=client):
            service = llm_service.OpenAIService(api_key="test-key", model="test-model")
            self.assertEqual(service.generate_text("prompt"), "narrative")
        request = client.chat.completions.create.call_args.kwargs
        self.assertEqual(request["model"], "test-model")
        self.assertEqual(request["temperature"], 0)
        self.assertEqual(request["max_tokens"], 200)

        response = MagicMock(status_code=200)
        response.json.return_value = {"choices": [{"message": {"content": "narrative"}}]}
        with patch.dict(sys.modules, {"openai": None}), patch.object(
                llm_service.requests, "post", return_value=response) as post:
            service = llm_service.OpenAIService(api_key="test-key", model="http-model")
            self.assertFalse(service.use_library)
            self.assertEqual(service.generate_text("prompt"), "narrative")
        payload = post.call_args.kwargs["json"]
        self.assertEqual(payload["temperature"], 0)
        self.assertEqual(payload["model"], "http-model")
        self.assertEqual(payload["max_tokens"], 200)

    def test_anthropic_sdk_and_http_send_zero(self):
        client = MagicMock()
        client.messages.create.return_value = SimpleNamespace(
            content=[SimpleNamespace(text="narrative")])
        sdk = SimpleNamespace(Anthropic=MagicMock(return_value=client))
        with patch.dict(sys.modules, {"anthropic": sdk}):
            service = llm_service.AnthropicService(api_key="test-key", model="test-claude")
            self.assertEqual(service.generate_text("prompt"), "narrative")
        request = client.messages.create.call_args.kwargs
        self.assertEqual(request["temperature"], 0)
        self.assertEqual(request["model"], "test-claude")
        self.assertEqual(request["max_tokens"], 200)

        response = MagicMock(status_code=200)
        response.json.return_value = {"content": [{"text": "narrative"}]}
        with patch.dict(sys.modules, {"anthropic": None}), patch.object(
                llm_service.requests, "post", return_value=response) as post:
            service = llm_service.AnthropicService(api_key="test-key", model="http-claude")
            self.assertFalse(service.use_library)
            self.assertEqual(service.generate_text("prompt"), "narrative")
        payload = post.call_args.kwargs["json"]
        self.assertEqual(payload["temperature"], 0)
        self.assertEqual(payload["model"], "http-claude")
        self.assertEqual(payload["max_tokens"], 200)

    def test_multi_agent_default_reaches_request(self):
        client = MagicMock()
        client.chat.completions.create.return_value = SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content="{}"))])
        with patch.object(multi_agents.openai, "OpenAI", return_value=client):
            analyzer = multi_agents.MultiAgentAnalyzer(model="test-model")
            analyzer._call_llm_api("unchanged prompt")
        request = client.chat.completions.create.call_args.kwargs
        self.assertEqual(request["temperature"], 0)
        self.assertEqual(request["model"], "test-model")
        self.assertEqual(request["messages"][0]["content"], "unchanged prompt")

    def test_narrative_default_reaches_http_request(self):
        conn = MagicMock()
        conn.getresponse.return_value.status = 200
        conn.getresponse.return_value.read.return_value = b'{"choices": []}'
        with patch.object(narrative_generator.http.client, "HTTPSConnection", return_value=conn):
            generator = narrative_generator.NarrativeGenerator(model="test-narrative")
            generator._call_llm_api("unchanged narrative prompt")
        payload = json.loads(conn.request.call_args.args[2])
        self.assertEqual(payload["temperature"], 0)
        self.assertEqual(payload["model"], "test-narrative")
        self.assertFalse(payload["stream"])

    def test_narrative_cli_propagates_model_and_key(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {}, clear=True), \
                patch.object(analyze_taint_paths, "analyze_all_contracts", return_value={"test": {}}) as run, \
                patch.object(sys, "argv", ["narratives", "--output-dir", directory,
                                          "--llm-model", "test-model", "--llm-api-key", "test-key"]):
            self.assertEqual(analyze_taint_paths.main(), 0)
            self.assertEqual(os.environ["LLM_MODEL"], "test-model")
            self.assertEqual(os.environ["LLM_KEY"], "Bearer test-key")
            run.assert_called_once()

    def test_narrative_cli_rejects_unimplemented_provider(self):
        with patch.object(sys, "argv", ["narratives", "--llm-service", "anthropic"]), \
                contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            analyze_taint_paths.main()
        self.assertEqual(error.exception.code, 2)


class EntrypointTests(unittest.TestCase):
    def test_main_model_default_and_override(self):
        for flags, model in [([], "gpt-4o"), (["--llm-model", "custom-model"], "custom-model")]:
            with self.subTest(model=model), patch.object(detector_cli, "init_directories", return_value=(None,) * 4), \
                    patch.object(detector_cli, "process_single_contract") as run, \
                    patch.object(sys, "argv", ["pmdetector", "--source-code", "test.sol"] + flags):
                detector_cli.main()
                self.assertEqual(run.call_args.args[0].llm_model, model)

    def test_pipeline_passes_model_zero_and_records_metadata(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.ExitStack() as stack:
            root = Path(directory)
            source = root / "fixture.sol"
            source.write_text("pragma solidity ^0.8.21; contract Fixture {}")
            stack.enter_context(patch.object(detector_cli, "__file__", str(root / "main.py")))
            detector_cli.init_directories()
            stack.enter_context(patch.object(detector_cli, "clean_flattened_contract", return_value=False))
            stack.enter_context(patch.object(detector_cli, "extract_solidity_version", return_value="0.8.21"))
            stack.enter_context(patch.object(detector_cli, "ensure_solc_version", return_value="/tmp/solc-v0.8.21"))
            stack.enter_context(patch("solcx.set_solc_version"))
            detector = stack.enter_context(patch.object(detector_cli, "TaintDetector"))
            detector.return_value.analyze_file.return_value = SimpleNamespace(paths=["synthetic path"])
            stack.enter_context(patch.object(detector_cli, "taint_result_to_source_text", return_value="## Path #1\nsynthetic"))
            stack.enter_context(patch.object(detector_cli, "create_taint_path_files"))
            analyzer = stack.enter_context(patch.object(detector_cli, "MultiAgentAnalyzer"))
            analyzer.return_value.analyze.return_value = {"is_vulnerable": True}
            stack.enter_context(patch.object(detector_cli, "apply_sanity_check", side_effect=lambda _, result, __: dict(result)))
            args = SimpleNamespace(contract_address=None, source_code=str(source), platform="ETH", llm_model="explicit-model")
            detector_cli.process_single_contract(args)
            analyzer.assert_called_once_with(model="explicit-model", temperature=0)
            for suffix in ["llm_result", "filtered_llm_result"]:
                result = json.loads((root / f"fixture_{suffix}.json").read_text())
                self.assertEqual(result["llm_config"], {"model": "explicit-model", "temperature": 0})
                self.assertTrue(result["is_vulnerable"])

    def test_installed_entrypoint_and_module_help(self):
        executable = Path(sys.executable).parent / "pmdetector"
        commands = [[str(executable), "--help"],
                    [sys.executable, "-m", "pmdetector.llm.analyze_taint_paths", "--help"],
                    [sys.executable, "-m", "experiments.analyze_results", "--help"]]
        for command in commands:
            with self.subTest(command=command):
                completed = subprocess.run(command, text=True, capture_output=True, timeout=30)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertIn("usage:", completed.stdout)


class StaticSummaryTests(unittest.TestCase):
    def test_path_presence_is_not_called_a_vulnerability(self):
        result = analyze_results.extract_summary_info("Found 2 tainted paths")
        self.assertTrue(result["has_taint_paths"])
        self.assertNotIn("has_vulnerability", result)
        self.assertFalse(analyze_results.extract_summary_info("Found 0 tainted paths")["has_taint_paths"])

    def test_summary_skips_incomplete_reports_and_writes_new_schema(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            results = root / "reports"
            results.mkdir()
            rows = []
            for i, text in enumerate(["Found 1 tainted paths", "Found 0 tainted paths", "Error during analysis"]):
                protocol, address = f"Test{i}", f"0x{i}"
                rows.append({"Protocol": protocol, "Contract Address": address, "Platform": "ETH", "Label": i % 2})
                contract_id = hashlib.md5(f"{protocol}_{address}_eth".encode()).hexdigest()[:8]
                (results / f"{contract_id}_test.txt").write_text(text)
            dataset = root / "dataset.xlsx"
            pd.DataFrame(rows).to_excel(dataset, index=False)
            destination = root / "new" / "summary.csv"
            historical = root / "analysis_summary.csv"
            historical.write_text("historical data")
            log = io.StringIO()
            with contextlib.redirect_stdout(log):
                analyze_results.main(dataset, results, destination)
            output = pd.read_csv(destination)
            self.assertEqual(len(output), 2)
            self.assertEqual(int(output.has_taint_paths.sum()), 1)
            self.assertNotIn("has_vulnerability", output.columns)
            self.assertIn("Skipping", log.getvalue())
            self.assertEqual(historical.read_text(), "historical data")
            for path in results.iterdir():
                path.unlink()
            analyze_results.main(dataset, results, destination)
            self.assertTrue(pd.read_csv(destination).empty)
            self.assertIn("has_taint_paths", pd.read_csv(destination).columns)

    def test_missing_dataset_argument_has_usage_error(self):
        completed = subprocess.run([sys.executable, "-m", "experiments.analyze_results"],
                                   text=True, capture_output=True, timeout=30)
        self.assertEqual(completed.returncode, 2)
        self.assertIn("--dataset", completed.stderr)
        self.assertNotIn("Traceback", completed.stderr)


if __name__ == "__main__":
    unittest.main()
