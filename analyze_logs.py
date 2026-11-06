#!/usr/bin/env python3
"""
Dark Matter - Server Log Investigator
Companion pattern analyzer script.
Analyzes server logs for HTTP errors, TLS certificate issues, timeouts,
Elasticsearch exceptions, and permission errors.
"""

import sys
import re
import json
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
    "ELASTICSEARCH_DB": {
        "ES_EXCEPTION": re.compile(r"elasticsearch|elasticsearchclient|cluster node", re.IGNORECASE),
        "CONNECTION_REFUSED": re.compile(r"connection refused|failed after \d+ retries", re.IGNORECASE),
        "POOL_EXHAUSTED": re.compile(r"connectionpool|pool exhausted|threshold", re.IGNORECASE),
    },
    "PERMISSION_SYSTEM": {
        "PERMISSION_DENIED": re.compile(r"permission denied|accessdeniedexception|permissiondenied|eacces", re.IGNORECASE),
        "MEMORY_PRESSURE": re.compile(r"outofmemoryerror|heap memory usage reached|garbage collection", re.IGNORECASE),
    }
}


def analyze_log_file(file_path: str) -> Dict[str, Any]:
    path = Path(file_path)
    if not path.is_file():
        return {"error": f"Log file not found: {file_path}"}

    total_lines = 0
    severity_counts = {"INFO": 0, "WARN": 0, "ERROR": 0, "CRITICAL": 0}
    findings: List[Dict[str, Any]] = []
    timeline: List[Dict[str, str]] = []

    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line_no, raw_line in enumerate(f, start=1):
            total_lines += 1
            line = raw_line.strip()
            if not line:
                continue

            # Severity extraction
            severity = "INFO"
            if "[CRITICAL]" in line or "CRITICAL" in line:
                severity = "CRITICAL"
                severity_counts["CRITICAL"] += 1
            elif "[ERROR]" in line or "ERROR" in line:
                severity = "ERROR"
                severity_counts["ERROR"] += 1
            elif "[WARN]" in line or "WARN" in line or "WARNING" in line:
                severity = "WARN"
                severity_counts["WARN"] += 1
            else:
                severity_counts["INFO"] += 1

            # Timestamp extraction (supports ISO or standard YYYY-MM-DD HH:MM:SS)
            ts_match = re.search(r"(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d{3})?)", line)
            timestamp = ts_match.group(1) if ts_match else f"Line {line_no}"

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
                    "summary": line[:160],
                    "categories": detected_categories
                }
                timeline.append(timeline_entry)
                if detected_categories:
                    findings.append(timeline_entry)

    # Root cause candidate scoring
    root_cause_candidates = []
    if any("TLS_SSL_ISSUES" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "TLS Certificate Expired / Handshake Failure",
            "confidence": "HIGH",
            "impact": "Authentication and secure communication channels failing"
        })
    if any("ELASTICSEARCH_DB" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Elasticsearch Cluster Unreachable / Connect Timeout",
            "confidence": "HIGH",
            "impact": "Search services and indexing backlog degraded"
        })
    if any("504" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Upstream Payment Gateway Timeout (HTTP 504)",
            "confidence": "HIGH",
            "impact": "Checkout transactions failing after 30s timeout window"
        })
    if any("PERMISSION_SYSTEM" in c for f in findings for c in f["categories"]):
        root_cause_candidates.append({
            "issue": "Filesystem Permission Denied & JVM Heap Spikes",
            "confidence": "MEDIUM",
            "impact": "Security audit logging blocked and garbage collection pauses"
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
    print(f"SEVERITY BREAKDOWN:")
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


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "sample.log"
    analysis = analyze_log_file(target)

    if "--json" in sys.argv:
        print(json.dumps(analysis, indent=2))
    else:
        print_markdown_report(analysis)
