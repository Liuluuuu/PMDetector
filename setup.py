#!/usr/bin/env python3
"""
Setup script for the PMDetector package.
"""

from setuptools import setup, find_packages

setup(
    name="pmdetector",
    version="0.1.0",
    description="A taint analysis tool for smart contracts",
    author="Smart Contract Researcher",
    packages=find_packages(),
    install_requires=[
        "slither-analyzer>=0.9.0",
        "requests>=2.25.0",
    ],
    entry_points={
        "console_scripts": [
            "pmdetector=pmdetector.main:main",
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
