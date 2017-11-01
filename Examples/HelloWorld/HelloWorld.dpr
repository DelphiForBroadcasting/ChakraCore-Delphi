program HelloWorld;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ChakraCore in '..\..\Include\ChakraCore.pas';

procedure FAIL_CHECK(errCode: JsErrorCode);
begin
  if (errCode <> JsNoError) then
  begin
    raise Exception.CreateFmt('Error %d', [integer(errCode)]);
  end;
end;


{
function reg_func(const name: PWideChar; function_pointer: JsNativeFunction): boolean;
var
  property_id : JsPropertyIdRef;
  errorCode: JsErrorCode;
  js_function : JsValueRef;
begin

  errorCode := JsGetPropertyIdFromName(name, property_id);
  if (errorCode <> JsNoError) then
  begin
   raise Exception.Create('Error Message');
  end;

  errorCode := JsCreateFunction(function_pointer, 0, js_function);
  if (errorCode <> JsNoError) then
  begin
    JsRelease(property_id, 0);
    raise Exception.Create('Error Message');
  end;

  errorCode := JsSetProperty(global_object, property_id, js_function, true);
  if (errorCode <> JsNoError) then
  begin
    JsRelease(property_id, 0);
    JsRelease(js_function, 0);
    raise Exception.Create('Error Message');
  end;
end; }


procedure HelloWorldTest;
var
  script: String;
  runtime: JsRuntimeHandle;
  context: JsContextRef;
  currentSourceContext: LongWord;
  result: JsValueRef;
  resultJSString: JsValueRef;
  resultWC: PWideChar;
  stringLength: NativeUInt;
  resultStr: String;
  js_type: JsValueType;

begin
  script := '(()=>{return ''Hello world!'';})()';

  // Create a runtime.
  FAIL_CHECK(JsCreateRuntime(JsRuntimeAttributeNone, nil, runtime));

  // Create an execution context.
  FAIL_CHECK(JsCreateContext(runtime, context));

  // Now set the execution context as being the current one on this thread.
  FAIL_CHECK(JsSetCurrentContext(context));

  // Run the script.
  FAIL_CHECK(JsRunScript(PWideChar(script), @currentSourceContext, PWideChar(''), result));

  FAIL_CHECK(JsGetValueType(result, js_type));
  if js_type = JsString then
  begin
    FAIL_CHECK(JsConvertValueToString(result, resultJSString));
    FAIL_CHECK(JsStringToPointer(resultJSString, resultWC, stringLength));
    setLength(resultStr, stringLength);
    move(resultWC[0], resultStr[1], stringLength * 2);
    WriteLn(String.Format('result is %s', [resultStr]));
  end;

  // Dispose runtime
  JsSetCurrentContext(JS_INVALID_REFERENCE);
  JsDisposeRuntime(runtime);  
end;

begin
  try
    HelloWorldTest;
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
