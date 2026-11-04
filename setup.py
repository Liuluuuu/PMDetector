#!/usr/bin/env python3
from setuptools import setup, find_packages

setup(
    name="pmdetector",
    version="0.1.0",
    description="A taint analysis tool for smart contracts",
    author="Smart Contract Researcher",
    packages=find_packages(),
    py_modules=["main", "cleanup_flattened_contracts"],
    install_requires=[
        "slither-analyzer>=0.9.0",
        "requests>=2.25.0",
        "openai>=1.0.0",
        "python-dotenv>=1.1.1",
        "pandas>=1.3.0",
        "openpyxl>=3.0.0",
        "py-solc-x==2.0.4",
    ],
    entry_points={
        "console_scripts": [
            "pmdetector=main:main",
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Quality Assurance",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
    ],
    python_requires=">=3.8",
)
