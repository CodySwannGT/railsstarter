#!/usr/bin/env python3
"""Local X-Ray CLI read protocol. No provider or credential resolution occurs."""
import json
import os
import sys

args = sys.argv[1:]
with open(os.environ["TELEMETRY_CALL_LOG"], "a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\n")
if os.environ.get("TELEMETRY_FAIL"):
    print("synthetic X-Ray read failure", file=sys.stderr)
    sys.exit(42)

service = os.environ["OTEL_SERVICE_NAME"]
operation = args[1]
if args[0] != "xray":
    sys.exit("unexpected service")

if operation == "get-trace-summaries":
    traces = [{"Id": "synthetic-trace", "Duration": 2, "HasFault": True,
               "Http": {"HttpStatus": 500, "HttpMethod": "GET", "HttpURL": "/synthetic"}}]
    if "--filter-expression" not in args:
        traces.append({"Id": "foreign-trace", "Duration": 1})
    print(json.dumps({"TraceSummaries": traces}))
elif operation == "get-service-graph":
    # The actual AWS operation accepts no filter-expression parameter.
    if "--filter-expression" in args:
        sys.exit("get-service-graph does not accept --filter-expression")
    print(json.dumps({"Services": [
        {"Name": service, "ReferenceId": 1, "Type": "AWS::ECS::Container",
         "Edges": [{"ReferenceId": 1}, {"ReferenceId": 2}], "SummaryStatistics": {"OkCount": 7}},
        {"Name": "foreign-service", "ReferenceId": 2, "Edges": []}]}))
elif operation == "batch-get-traces":
    documents = [{"name": name, "start_time": 1, "end_time": 3} for name in [service, "foreign-service"]]
    if os.environ.get("TELEMETRY_FOREIGN_TRACE"):
        documents = documents[1:]
    print(json.dumps({"Traces": [{"Id": "synthetic-trace", "Segments": [
        {"Document": json.dumps(document)} for document in documents]}]}))
else:
    sys.exit("unexpected operation")
