program Callback;

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

function JSValueToString(value: JsValueRef): string;
var
  retCode: JsErrorCode;
  JsStringValue: JsValueRef;
  outString : PWideChar;
  outStringLength : NativeUInt;
  valueType : JsValueType;
begin
  result := '';
  retCode := JsGetValueType(value,valueType);
  if retCode <> JsNoError then
  begin
    raise Exception.CreateFmt('Error JsGetValueType with code %d', [Integer(retCode)]);
  end;

  if valueType = JsString then
  begin
    JsStringValue := value
  end else
  begin
    retCode := JsConvertValueToString(value, JsStringValue);
    if retCode <> JsNoError then
      raise Exception.CreateFmt('Error JsConvertValueToString with code %d', [Integer(retCode)]);
  end;

  retCode := JsStringToPointer(JsStringValue, outString, outStringLength);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsStringToPointer with code %d', [Integer(retCode)]);
  setLength(result, outStringLength);
  move(outString[0], result[1], outStringLength * SizeOf(WideChar));
end;

function callback_func(callee: JsValueRef; isConstructCall: boolean;  arguments: PJsValueRef; argumentCount: Word; callbackState: Pointer): JsValueRef; stdcall;
var
  i         : integer;
  argument  : PJsValueRef;
  global    : PJsValueRef;
begin
  for I := 0 to argumentCount - 1 do
  begin
    writeln(JSValueToString(arguments^));
    inc(arguments);
  end;

  result := nil;
end;


function RegisterFunction(const name: PWideChar; func: JsNativeFunction; state: Pointer): boolean;
var
  idref     : JsPropertyIdRef;
  retCode   : JsErrorCode;
  ref       : JsValueRef;
  global    : JsValueRef;
begin
  JsGetGlobalObject(global);

  retCode := JsCreateFunction(func, state, ref);
  if (retCode <> JsNoError) then
    raise Exception.CreateFmt('Error JsGetProperty with code %d', [Integer(retCode)]);

  retCode := JsGetPropertyIdFromName(name, idref);
  if (retCode <> JsNoError) then
    raise Exception.CreateFmt('Error JsGetProperty with code %d', [Integer(retCode)]);

  retCode := JsSetProperty(global, idref, ref, true);
  if (retCode <> JsNoError) then
    raise Exception.CreateFmt('Error JsGetProperty with code %d', [Integer(retCode)]);

end;


var
  script: String;
  runtime: JsRuntimeHandle;
  context: JsContextRef;
  currentSourceContext: LongWord;
  result: JsValueRef;
  ref_func  : JsValueRef;
  idref     : JsPropertyIdRef;
begin
  try
    ReportMemoryLeaksOnShutdown := true;

    script := 'test_function("1", 1, 1.00, true, {value:1}, [1, 2, 3, 4, 5]);';

    // Create a runtime.
    FAIL_CHECK(JsCreateRuntime(JsRuntimeAttributeNone, nil, runtime));

    // Create an execution context.
    FAIL_CHECK(JsCreateContext(runtime, context));

    // Now set the execution context as being the current one on this thread.
    FAIL_CHECK(JsSetCurrentContext(context));

    // Register function
    RegisterFunction('test_function', callback_func, nil);

    // Run the script.
    FAIL_CHECK(JsRunScript(PWideChar(script), @currentSourceContext, PWideChar(''), result));

    // Dispose runtime
    JsSetCurrentContext(JS_INVALID_REFERENCE);
    JsDisposeRuntime(runtime);

    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
