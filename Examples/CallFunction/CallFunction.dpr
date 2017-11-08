program CallFunction;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Rtti,
  ChakraCore in '..\..\Include\ChakraCore.pas';

procedure FAIL_CHECK(errCode: JsErrorCode);
begin
  if (errCode <> JsNoError) then
  begin
    raise Exception.CreateFmt('Error %d', [integer(errCode)]);
  end;
end;


function StringToJSValue(value: string): JsValueRef;
var
  retCode : JsErrorCode;
begin
  retCode := JsPointerToString(PWideChar(value), value.Length, result);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsPointerToString with code %d', [Integer(retCode)]);
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


function callJsFunction(func_name: string; arguments: TArray<TValue>): TValue;
var
  retCode : JsErrorCode;
  global : JsValueRef;
  idref: JsPropertyIdRef;
  jsFunc : JsValueRef;
  jsArguments : array of JsValueRef;
  arg : TValue;
  i : integer;
  retValue : JsValueRef;
  JsValueArg : JsValueRef;
  ValueType : JsValueType;
  IntValue : integer;
  BoolValue : boolean;
begin
  JsGetGlobalObject(global);

  // get property
  retCode := JsGetPropertyIdFromName(PWideChar(func_name), idref);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsGetPropertyIdFromName with code %d', [Integer(retCode)]);

  retCode := JsGetProperty(global, idref, jsFunc);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsGetProperty with code %d', [Integer(retCode)]);

  // convert args
  SetLength(jsArguments, Length(arguments) + 1);
  jsArguments[0]:= global;
  i := 1;
  for arg in arguments do
  begin
    JsValueArg := nil;
    case arg.Kind of
      tkString, tkLString, tkWString, tkWChar, tkChar,  tkUString:
      begin
        JsPointerToString(PWideChar(arg.AsString), arg.AsString.Length, JsValueArg);
      end;
      tkInteger, tkInt64:
      begin
        JsIntToNumber(arg.AsInt64, JsValueArg);
      end;
      tkFloat:
      begin
        JsDoubleToNumber(arg.AsExtended, JsValueArg);
      end
      else
      begin
        JsGetNullValue(JsValueArg);
      end;
    end;
    jsArguments[i] := JsValueArg;
    inc(i);
  end;

  // call function
  retCode := JsCallFunction(jsFunc, PJsValueRef(jsArguments), Length(jsArguments), retValue);
  if retCode <> JsNoError then
  begin
    raise Exception.Create('couldn''t execute function');
  end;

  // convert function return value
  retCode := JsGetValueType(retValue, ValueType);
  if retCode <> JsNoError then
    raise Exception.Create('Error Message');
  case ValueType of
    JsNumber:
      begin
        JsNumberToInt(retValue, IntValue);
        result := TValue.From<integer>(IntValue);
      end;
    JsString:
      begin
        result := TValue.From<string>(JSValueToString(retValue));
      end;
    JsBoolean:
      begin
        JsBooleanToBool(retValue, BoolValue);
        result := TValue.From<boolean>(BoolValue);
      end
    else begin
      result := TValue.From<string>(JSValueToString(retValue));
    end;
  end;
end;

var
  script: String;
  runtime: JsRuntimeHandle;
  context: JsContextRef;
  currentSourceContext: LongWord;
  result: JsValueRef;
begin
  try
    ReportMemoryLeaksOnShutdown := true;

    script := ' function a(a, b){  return a * b; } ';

    // Create a runtime.
    FAIL_CHECK(JsCreateRuntime(JsRuntimeAttributeNone, nil, runtime));

    // Create an execution context.
    FAIL_CHECK(JsCreateContext(runtime, context));

    // Now set the execution context as being the current one on this thread.
    FAIL_CHECK(JsSetCurrentContext(context));

    // Run the script.
    FAIL_CHECK(JsRunScript(PWideChar(script), @currentSourceContext, PWideChar(''), result));

    writeln(callJsFunction('a', [TValue.From<integer>(5), TValue.From<integer>(5)]).ToString);

    // Dispose runtime
    JsSetCurrentContext(JS_INVALID_REFERENCE);
    JsDisposeRuntime(runtime);


    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
