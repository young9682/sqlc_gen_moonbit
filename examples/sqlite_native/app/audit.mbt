///|
#derive(Debug)
suberror AuditError {
  AuditError(String)
}

///|
let audit_question = "Which accounts remain with a user ID of at least 1?"

///|
let audit_plan =
  #|{"plan":{"from_table":"users",
  #|"select":[["Column",{"table":"users","column":"id"}],["Column",{"table":"users","column":"name"}],["Column",{"table":"users","column":"email"}]],
  #|"joins":[],"filters":[["Compare",{"table":"users","column":"id"},"GreaterEqual",["Integer","1"]]],
  #|"group_by":[],"order_by":[{"position":1,"descending":false}]}}

///|
async fn audit(path : String) -> Unit {
  guard @planner.ask(path, audit_question, (_, _) => audit_plan)
    is Queried(evidence) else {
    raise AuditError("The account audit did not return a result.")
  }
  let output : Json = {
    "question": Json::string(audit_question),
    "sql": Json::string(evidence.sql),
    "params": @json.to_json(evidence.params),
    "result": @json.to_json(evidence.result),
  }
  println(output.stringify(indent=2))
}
