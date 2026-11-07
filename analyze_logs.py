#!/usr/bin/env python3
"""
Dark Matter - Server Log Investigator
Companion pattern analyzer script.
Analyzes server logs for HTTP errors, TLS certificate issues, timeouts,
database connection exhaustion, Elasticsearch exceptions, and permission errors.
"""

import sys
import re
import json
import argparse
from pathlib import Path
from typing import Dict, List, Any


PATTERNS = {
    "HTTP_ERRORS": {
        "500": re.compile(r"\b500\b|Internal Server Error", re.IGNORECASE),
        "501": re.compile(r"\b501\b|Not Implemented", re.IGNORECASE),
        "502": re.compile(r"\b502\b|Bad Gateway", re.IGNORECASE),
        "503": re.compile(r"\b503\b|Service Unavailable", re.IGNORECASE),
        "504": re.compile(r"\b504\b|Gateway Timeout", re.IGNORECASE),
    },
    "TLS_SSL_ISSUES": {
        "CERT_EXPIRED": re.compile(r"certificate expired|expired certificate|certpathbuilderexception|unable to find valid certification path", re.IGNORECASE),
        "HANDSHAKE_FAIL": re.compile(r"sslhandshakeexception|handshake_failure|tls handshake failed", re.IGNORECASE),
        "HOSTNAME_MISMATCH": re.compile(r"hostname mismatch|certificate name mismatch", re.IGNORECASE),
    },
    "TIMEOUTS": {
        "CONNECTION_TIMEOUT": re.compile(r"connecttimeout|connection timed out|timed out after|timeout window", re.IGNORECASE),
        "READ_TIMEOUT": re.compile(r"readtimedout|read timeout", re.IGNORECASE),
    },
    "DATABASE": {
        "POOL_SLOW": re.compile(r"connectionpool.*approaching threshold|database connection checkout", re.IGNORECASE),
        "POOL_EXHAUSTED": re.compile(r"connectionpool exhausted|pool limit reached|max pool size exceeded", re.IGNORECASE),
    },
    "ELASTICSEARCH": {
        "ES_EXCEPTION": re.compile(r"elasticsearch|elasticsearchclient|restclient.*elasticsearch", re.IGNORECASE),
        "NODE_REFUSED": re.compile(r"connection refused to.*9200|cluster node", re.IGNORECASE),
    },
    "SYSTEM_MEMORY": {
        "HEAP_PRESSURE": re.compile(r"outofmemoryerror|heap memory usage reached|garbage collection", re.IGNORECASE),
    },
    "FILESYSTEM": {
        "PERMISSION_DENIED": re.compile(r"permission denied|accessdeniedexception|permissiondenied|eacces", re.IGNORECASE),
    }
}

# Timestamp extraction regex covering ISO 8601, Syslog, Apache Common Log Format
TIMESTAMP_REGEX = re.compile(
    r"(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?|"
    r"[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}|"
    r"\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2}\s+[+-]\d{4})"
)

# Severity structured regex
SEVERITY_REGEX = re.compile(
    r"\[(CRITICAL|FATAL|ERROR|WARN(?:ING)?|INFO|DEBUG|TRACE)\]|\b(CRITICAL|FATAL|ERROR|WARNING)\b",
    re.IGNORECASE
)


def analyze_log_file(file_path: str) -> Dict[str, Any]:
    path = Path(file_path)
    if not path.is_file():
        return {"error": f"Log file not found: {file_path}"}

    total_lines = 0
    severity_counts = {"INFO": 0, "WARN": 0, "ERROR": 0, "CRITICAL": 0}
    findings: List[Dict[str, Any]] = []
    timeline: List[Dict[str, Any]] = []

    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line_no, raw_line in enumerate(f, start=1):
            total_lines += 1
            line = raw_line.strip()
            if not line:
                continue

            # Severity extraction with word boundaries
            sev_match = SEVERITY_REGEX.search(line)
            severity = "INFO"
            if sev_match:
                raw_sev = (sev_match.group(1) or sev_match.group(2)).upper()
                if raw_sev in ("FATAL", "CRITICAL"):
                    severity = "CRITICAL"
                    severity_counts["CRITICAL"] += 1
                elif raw_sev == "ERROR":
                    severity = "ERROR"
                    severity_counts["ERROR"] += 1
                elif raw_sev in ("WARN", "WARNING"):
                    severity = "WARN"
                    severity_counts["WARN"] += 1
                elif raw_sev in ("INFO", "DEBUG", "TRACE"):
                    severity = "INFO"
                    severity_counts["INFO"] += 1
            else:
                severity_counts["INFO"] += 1

            # Timestamp extraction
            ts_match = TIMESTAMP_REGEX.search(line)
            timestamp = ts_match.group(1) if ts_match else f"Line {line_no}"

            # Summary cleanup: strip duplicate timestamp prefix if present
            cleaned_summary = line
            if ts_match:
                ts_span = ts_match.span()
                # If timestamp is at or near the start, strip it from summary
                if ts_span[0] < 10:
                    cleaned_summary = line[ts_span[1]:].lstrip(" -:[")

            # Check for error patterns
            detected_categories = []
            for category, pattern_dict in PATTERNS.items():
                for subcategory, regex in pattern_dict.items():
                    if regex.search(line):
                        detected_categories.append(f"{category}:{subcategory}")

            if detected_categories or severity in ("ERROR", "CRITICAL", "WARN"):
                timeline_entry = {
                    "timestamp": timestamp,
                    "line": line_no,
                    "severity": severity,
                    "summary": cleaned_summary[:160],
                    "categories": detected_categories
                }
                timeline.append(timeline_entry)
                if detected_categories:
                    findings.append(timeline_entry)

    # Root cause candidate deduction
    root_cause_candidates = []

    # TLS / SSL Certificate issues
    if any("TLS_SSL_ISSUES" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "TLS Certificate Expired / Handshake Failure",
            "confidence": "HIGH",
            "impact": "Authentication and secure communication channels failing"
        })

    # Elasticsearch cluster issues
    if any("ELASTICSEARCH" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Elasticsearch Cluster Unreachable / Connect Timeout",
            "confidence": "HIGH",
            "impact": "Search services and indexing backlog degraded"
        })

    # Database pool slow / exhaustion issues
    if any("DATABASE:POOL_EXHAUSTED" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Database Connection Pool Exhaustion",
            "confidence": "HIGH",
            "impact": "Backend workers blocked waiting for database connections"
        })

    # HTTP 5xx Errors
    if any("HTTP_ERRORS:504" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Payment Gateway Timeout Cascade (HTTP 504)",
            "confidence": "HIGH",
            "impact": "Checkout transactions failing after 30s timeout window"
        })
    if any("HTTP_ERRORS:503" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Service Unavailable / Downstream Outage (HTTP 503)",
            "confidence": "HIGH",
            "impact": "Downstream service offline, search engine unreachable, or capacity exhausted"
        })
    if any("HTTP_ERRORS:502" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Bad Gateway / Proxy Upstream Unreachable (HTTP 502)",
            "confidence": "HIGH",
            "impact": "Reverse proxy or gateway cannot communicate with upstream backend"
        })
    if any("HTTP_ERRORS:500" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Internal Server Application Error (HTTP 500)",
            "confidence": "HIGH",
            "impact": "Unhandled server exception impacting request execution"
        })

    # JVM Heap Memory Pressure
    if any("SYSTEM_MEMORY" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "JVM Heap Memory Pressure & Major GC Overhead",
            "confidence": "MEDIUM",
            "impact": "Elevated thread pause times and latency spikes"
        })

    # Filesystem Permission Denied
    if any("FILESYSTEM" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Filesystem Permission Denied on Critical Log Files",
            "confidence": "HIGH",
            "impact": "Security audit logging and diagnostic tracing blocked"
        })

    return {
        "file": str(path.resolve()),
        "total_lines": total_lines,
        "severity_summary": severity_counts,
        "total_anomalies_detected": len(findings),
        "root_cause_candidates": root_cause_candidates,
        "incident_timeline": timeline
    }


def print_markdown_report(report: Dict[str, Any]) -> None:
    if "error" in report:
        print(f"Error: {report['error']}", file=sys.stderr)
        return

    print("================================================================================")
    print("                    DARK MATTER - SERVER LOG INVESTIGATOR REPORT                ")
    print("================================================================================")
    print(f"Target File: {report['file']}")
    print(f"Total Lines Analyzed: {report['total_lines']}")
    print(f"Total Anomalies Flagged: {report['total_anomalies_detected']}\n")

    sev = report['severity_summary']
    print("SEVERITY BREAKDOWN:")
    print(f"  - CRITICAL: {sev['CRITICAL']}")
    print(f"  - ERROR:    {sev['ERROR']}")
    print(f"  - WARNING:  {sev['WARN']}")
    print(f"  - INFO:     {sev['INFO']}\n")

    print("ROOT CAUSE CANDIDATES:")
    for rc in report.get("root_cause_candidates", []):
        print(f"  [{rc['confidence']} CONFIDENCE] {rc['issue']}")
        print(f"    Impact: {rc['impact']}")
    print()

    print("CHRONOLOGICAL INCIDENT TIMELINE:")
    for item in report.get("incident_timeline", []):
        cat_str = f" ({', '.join(item['categories'])})" if item['categories'] else ""
        print(f"  {item['timestamp']} [{item['severity']}] Line {item['line']}: {item['summary']}{cat_str}")
    print("================================================================================")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Dark Matter - Autonomous Server Log Investigator"
    )
    parser.add_argument(
        "file",
        nargs="?",
        default="sample.log",
        help="Path to server log file (default: sample.log)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output analysis in JSON format"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    analysis = analyze_log_file(args.file)

    if "error" in analysis:
        print(f"Error: {analysis['error']}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(analysis, indent=2))
    else:
        print_markdown_report(analysis)
    sys.exit(0)
