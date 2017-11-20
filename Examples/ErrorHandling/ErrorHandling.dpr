program ErrorHandling;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ChakraCore in '..\..\Include\ChakraCore.pas';

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

function jsErrorToString(error : JsErrorCode):string;
begin
  case error of
    JsErrorInvalidArgument   : result := 'InvalidArgument';
    JsErrorNullArgument      : result := 'NullArgument';
    JsErrorArgumentNotObject : result := 'ArgumentNotAnObject';
    JsErrorOutOfMemory       : result := 'OutOfMemory';
    JsErrorScriptException   : result := 'ScriptError';
    JsErrorScriptCompile     : result := 'SyntaxError';
    JsErrorFatal             : result := 'FatalError"';
    JsErrorInExceptionState  : result := 'ErrorInExceptionState';
    else
      result := 'error code : ' + IntToStr(integer(error));
  end;
end;

function jsExceptionToString(): string;
var
  exceptObj         : JsValueRef;
  valueType         : JsValueType;
  retCode           : JsErrorCode;
  propertyNames     : JsValueRef;
  propertyRef       : JsValueRef;
  idref             : JsPropertyIdRef;
  valueRef          : JsValueRef;
  indexRef          : JsValueRef;

  namecount         : integer;
  i                 : integer;
  propertyNameStr   : string;
begin

  retCode:= jsGetAndClearException(exceptObj);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsStringToPointer with code %d', [Integer(retCode)]);

  retCode:= JsGetValueType(exceptObj, valueType);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsStringToPointer with code %d', [Integer(retCode)]);

  if (valueType <> JsObject) and (valueType <> jsError) then
  begin
    writeln(JSValueToString(exceptObj));
    exit;
  end;

  retCode:= JsGetOwnPropertyNames(exceptObj, propertyNames);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsStringToPointer with code %d', [Integer(retCode)]);

  // get Own Object PropertyNames length
  retCode:= JsGetPropertyIdFromName('length', idref);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsGetPropertyIdFromName with code %d', [Integer(retCode)]);
  retCode:= JsGetProperty(propertyNames, idref, valueRef);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsGetProperty with code %d', [Integer(retCode)]);
  retCode:= JsGetValueType(valueRef, valueType);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsGetValueType with code %d', [Integer(retCode)]);
  if JsNumber <> valueType then
    raise Exception.Create('Error Value type is not JsNumber');
  retCode:= JsNumberToInt(valueRef, namecount);
  if retCode <> JsNoError then
    raise Exception.CreateFmt('Error JsNumberToInt with code %d', [Integer(retCode)]);

  for I := 0 to namecount - 1 do
  begin
    if JsIntToNumber(i, indexRef) = JsNoError then
    begin
      if JsGetIndexedProperty(propertyNames, indexRef, propertyRef) = JsNoError then
      begin
        propertyNameStr := JSValueToString(propertyRef);
        write(propertyNameStr + ': ');
        if JsGetPropertyIdFromName(PWideChar(propertyNameStr), idref) = JsNoError then
        begin
          if JsGetProperty(exceptObj, idref, propertyRef) = JsNoError then
          begin
            writeln(JSValueToString(propertyRef));
          end;
        end;
      end;
    end;
  end;
end;

procedure FAIL_CHECK(errCode: JsErrorCode);
begin
  if (errCode <> JsNoError) then
  begin
    writeln(jsErrorToString(errCode));
    jsExceptionToString;
    //raise Exception.CreateFmt('Error %d', [integer(errCode)]);
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

    script := 'a.a;';

    // Create a runtime.
    FAIL_CHECK(JsCreateRuntime(JsRuntimeAttributeNone, nil, runtime));

    // Create an execution context.
    FAIL_CHECK(JsCreateContext(runtime, context));

    // Now set the execution context as being the current one on this thread.
    FAIL_CHECK(JsSetCurrentContext(context));

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
