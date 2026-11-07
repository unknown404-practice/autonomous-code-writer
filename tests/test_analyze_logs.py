import json
import pytest
from pathlib import Path
from analyze_logs import analyze_log_file, parse_args

def test_analyze_sample_log():
    result = analyze_log_file("sample.log")
    assert "error" not in result
    assert result["total_lines"] == 18
    assert result["severity_summary"]["CRITICAL"] >= 1
    assert result["severity_summary"]["ERROR"] >= 5
    assert len(result["root_cause_candidates"]) >= 2

def test_analyze_missing_file():
    result = analyze_log_file("non_existent_file.log")
    assert "error" in result
    assert "not found" in result["error"].lower()

def test_analyze_empty_file(tmp_path):
    empty_log = tmp_path / "empty.log"
    empty_log.write_text("")
    result = analyze_log_file(str(empty_log))
    assert "error" not in result
    assert result["total_lines"] == 0
    assert result["total_anomalies_detected"] == 0

def test_decoupled_database_and_elasticsearch(tmp_path):
    db_log = tmp_path / "db.log"
    db_log.write_text("2026-11-06 08:00:00 [WARN] org.example.db.ConnectionPool - checkout took 900ms\n")
    result = analyze_log_file(str(db_log))
    # Must NOT report Elasticsearch cluster failure when only database pool is mentioned
    issues = [c["issue"] for c in result.get("root_cause_candidates", [])]
    assert not any("Elasticsearch" in i for i in issues)

def test_http_500_and_503_root_causes(tmp_path):
    err_log = tmp_path / "errors.log"
    err_log.write_text(
        "2026-11-06 08:00:00 [ERROR] GET /api/checkout status=500 Internal Server Error\n"
        "2026-11-06 08:00:05 [ERROR] GET /api/search status=503 Service Unavailable: Search engine unreachable\n"
    )
    result = analyze_log_file(str(err_log))
    issues = [c["issue"] for c in result.get("root_cause_candidates", [])]
    assert any("500" in i or "Internal Server" in i for i in issues)
    assert any("503" in i or "Service Unavailable" in i for i in issues)

def test_memory_and_filesystem_decoupling(tmp_path):
    mem_log = tmp_path / "mem.log"
    mem_log.write_text("2026-11-06 08:00:00 [WARN] JVM Heap memory usage reached 90.0%\n")
    result = analyze_log_file(str(mem_log))
    issues = [c["issue"] for c in result.get("root_cause_candidates", [])]
    assert any("Memory Pressure" in i or "Heap" in i for i in issues)
    assert not any("Permission Denied" in i for i in issues)

def test_safe_word_boundary_severity(tmp_path):
    safe_log = tmp_path / "safe.log"
    safe_log.write_text("2026-11-06 08:00:00 [INFO] metrics: error_count=0, warn_threshold=disabled\n")
    result = analyze_log_file(str(safe_log))
    assert result["severity_summary"]["ERROR"] == 0
    assert result["severity_summary"]["WARN"] == 0
