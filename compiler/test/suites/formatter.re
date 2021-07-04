open Grain_tests.TestFramework;
open Grain_tests.Runner;

describe("formatter", ({test}) => {
  let assertFormatOutput = makeFormatterRunner(test);

  assertFormatOutput("function_params", "function_params");
  assertFormatOutput("variants", "variants");
  assertFormatOutput("matches", "matches");
  assertFormatOutput("imports", "imports");
  assertFormatOutput("wasm", "wasm");
  // assertFormatOutput("spreads", "spreads");
  // assertFormatOutput("nested_matches", "nested_matches");
  assertFormatOutput("number_sugar", "number_sugar");
});
