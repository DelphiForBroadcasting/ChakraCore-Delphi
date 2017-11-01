//-------------------------------------------------------------------------------------------------------
// Copyright (C) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.txt file in the project root for full license information.
//-------------------------------------------------------------------------------------------------------
/// \mainpage Chakra Hosting API Reference
///
/// Chakra is Microsoft's JavaScript engine. It is an integral part of Internet Explorer but can
/// also be hosted independently by other applications. This reference describes the APIs available
/// to applications to host Chakra.
///

/// \file
/// \brief The Chakra Core hosting API.
///
/// This file contains a flat C API layer. This is the API exported by ChakraCore.dll.


unit ChakraCore;

{$MINENUMSIZE 4}

interface

uses
  System.SysUtils;

const
{$IF DEFINED(MSWINDOWS)}
  {$IFDEF CPUX64}
  CHAKRA_LIB = 'ChakraCore.dll';
  {$ENDIF}
  {$IFDEF CPUX86}
  CHAKRA_LIB = 'ChakraCore.dll';
  {$ENDIF}
{$ELSEIF DEFINED(MACOS)}
  CHAKRA_LIB = '@executable_path/../Frameworks/libChakraCore.dylib';
{$ELSEIF DEFINED(UNIX)}
  CHAKRA_LIB = 'libChakraCore.so';
{$IFEND}

{$DEFINE _CHAKRACORE_H_}
{$INCLUDE ChakraCoreVersion.pas}

{$INCLUDE ChakraCommon.pas}
{$INCLUDE ChakraDebug.pas}

type
  JsModuleRecord = System.Pointer;

  // <summary>
  /// A reference to an object owned by the SharedArrayBuffer.
  /// </summary>
  /// <remarks>
  /// This represents SharedContents which is heap allocated object, it can be passed through
  /// different runtimes to share the underlying buffer.
  /// </remarks>
  JsSharedArrayBufferContentHandle = System.Pointer;

  JsParseModuleSourceFlags =
  (
    JsParseModuleSourceFlags_DataIsUTF16LE = $00000000,
    JsParseModuleSourceFlags_DataIsUTF8 = $00000001
  );

  JsModuleHostInfoKind =
  (
    JsModuleHostInfo_Exception = $01,
    JsModuleHostInfo_HostDefined = $02,
    JsModuleHostInfo_NotifyModuleReadyCallback = $3,
    JsModuleHostInfo_FetchImportedModuleCallback = $4,
    JsModuleHostInfo_FetchImportedModuleFromScriptCallback = $5
  );

type
  /// <summary>
  /// User implemented callback to fetch additional imported modules.
  /// </summary>
  /// <remarks>
  /// Notify the host to fetch the dependent module. This is the "import" part before HostResolveImportedModule in ES6 spec.
  /// This notifies the host that the referencing module has the specified module dependency, and the host need to retrieve the module back.
  /// </remarks>
  /// <param name="referencingModule">The referencing module that is requesting the dependency modules.</param>
  /// <param name="specifier">The specifier coming from the module source code.</param>
  /// <param name="dependentModuleRecord">The ModuleRecord of the dependent module. If the module was requested before from other source, return the
  /// existing ModuleRecord, otherwise return a newly created ModuleRecord.</param>
  /// <returns>
  /// true if the operation succeeded, false otherwise.
  /// </returns>
  FetchImportedModuleCallBack = function(referencingModule: JsModuleRecord; specifier: JsValueRef; var dependentModuleRecord: JsModuleRecord): JsErrorCode; stdcall;

type
  /// <summary>
  /// User implemented callback to get notification when the module is ready.
  /// </summary>
  /// <remarks>
  /// Notify the host after ModuleDeclarationInstantiation step (15.2.1.1.6.4) is finished. If there was error in the process, exceptionVar
  /// holds the exception. Otherwise the referencingModule is ready and the host should schedule execution afterwards.
  /// </remarks>
  /// <param name="referencingModule">The referencing module that have finished running ModuleDeclarationInstantiation step.</param>
  /// <param name="exceptionVar">If nullptr, the module is successfully initialized and host should queue the execution job
  /// otherwise it's the exception object.</param>
  /// <returns>
  /// true if the operation succeeded, false otherwise.
  /// </returns>
  FetchImportedModuleFromScriptCallBack = function(dwReferencingSourceContext: JsSourceContext; specifier: JsValueRef; var dependentModuleRecord: JsModuleRecord): JsErrorCode; stdcall;

  type
  /// <summary>
  /// User implemented callback to get notification when the module is ready.
  /// </summary>
  /// <remarks>
  /// Notify the host after ModuleDeclarationInstantiation step (15.2.1.1.6.4) is finished. If there was error in the process, exceptionVar
  /// holds the exception. Otherwise the referencingModule is ready and the host should schedule execution afterwards.
  /// </remarks>
  /// <param name="dwReferencingSourceContext">The referencing script that calls import()</param>
  /// <param name="exceptionVar">If nullptr, the module is successfully initialized and host should queue the execution job
  /// otherwise it's the exception object.</param>
  /// <returns>
  /// true if the operation succeeded, false otherwise.
  /// </returns>
  NotifyModuleReadyCallback = function(referencingModule: JsModuleRecord; exceptionVar: JsValueRef): JsErrorCode; stdcall;

/// <summary>
///     Initialize a ModuleRecord from host
/// </summary>
/// <remarks>
///     Bootstrap the module loading process by creating a new module record.
/// </remarks>
/// <param name="referencingModule">The referencingModule as in HostResolveImportedModule (15.2.1.17). nullptr if this is the top level module.</param>
/// <param name="normalizedSpecifier">The host normalized specifier. This is the key to a unique ModuleRecord.</param>
/// <param name="moduleRecord">The new ModuleRecord created. The host should not try to call this API twice with the same normalizedSpecifier.
///                           chakra will return an existing ModuleRecord if the specifier was passed in before.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsInitializeModuleRecord(referencingModule: JsModuleRecord; normalizedSpecifier: JsValueRef; var moduleRecord: JsModuleRecord): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsInitializeModuleRecord' {$ENDIF};

/// <summary>
///     Parse the module source
/// </summary>
/// <remarks>
/// This is basically ParseModule operation in ES6 spec. It is slightly different in that the ModuleRecord was initialized earlier, and passed in as an argument.
/// </remarks>
/// <param name="requestModule">The ModuleRecord that holds the parse tree of the source code.</param>
/// <param name="sourceContext">A cookie identifying the script that can be used by debuggable script contexts.</param>
/// <param name="script">The source script to be parsed, but not executed in this code.</param>
/// <param name="scriptLength">The source length of sourceText. The input might contain embedded null.</param>
/// <param name="sourceFlag">The type of the source code passed in. It could be UNICODE or utf8 at this time.</param>
/// <param name="exceptionValueRef">The error object if there is parse error.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsParseModuleSource(requestModule: JsModuleRecord; sourceContext: JsSourceContext; script: PByte; scriptLength: cardinal; sourceFlag: JsParseModuleSourceFlags; var exceptionValueRef: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsParseModuleSource' {$ENDIF};

/// <summary>
///     Execute module code.
/// </summary>
/// <remarks>
///     This method implements 15.2.1.1.6.5, "ModuleEvaluation" concrete method.
///     When this methid is called, the chakra engine should have notified the host that the module and all its dependent are ready to be executed.
///     One moduleRecord will be executed only once. Additional execution call on the same moduleRecord will fail.
/// </remarks>
/// <param name="requestModule">The module to be executed.</param>
/// <param name="result">The return value of the module.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsModuleEvaluation(requestModule: JsModuleRecord; var result: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsModuleEvaluation' {$ENDIF};

/// <summary>
///     Set the host info for the specified module.
/// </summary>
/// <param name="requestModule">The request module.</param>
/// <param name="moduleHostInfo">The type of host info to be set.</param>
/// <param name="hostInfo">The host info to be set.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsSetModuleHostInfo(requestModule: JsModuleRecord; moduleHostInfo: JsModuleHostInfoKind; hostInfo: Pointer): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsSetModuleHostInfo' {$ENDIF};

/// <summary>
///     Retrieve the host info for the specified module.
/// </summary>
/// <param name="requestModule">The request module.</param>
/// <param name="moduleHostInfo">The type of host info to get.</param>
/// <param name="hostInfo">The host info to be retrieved.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsGetModuleHostInfo(requestModule: JsModuleRecord; moduleHostInfo: JsModuleHostInfoKind; var hostInfo: Pointer): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsGetModuleHostInfo' {$ENDIF};

/// <summary>
///     Returns metadata relating to the exception that caused the runtime of the current context
///     to be in the exception state and resets the exception state for that runtime. The metadata
///     includes a reference to the exception itself.
/// </summary>
/// <remarks>
///     <para>
///     If the runtime of the current context is not in an exception state, this API will return
///     <c>JsErrorInvalidArgument</c>. If the runtime is disabled, this will return an exception
///     indicating that the script was terminated, but it will not clear the exception (the
///     exception will be cleared if the runtime is re-enabled using
///     <c>JsEnableRuntimeExecution</c>).
///     </para>
///     <para>
///     The metadata value is a javascript object with the following properties: <c>exception</c>, the
///     thrown exception object; <c>line</c>, the 0 indexed line number where the exception was thrown;
///     <c>column</c>, the 0 indexed column number where the exception was thrown; <c>length</c>, the
///     source-length of the cause of the exception; <c>source</c>, a string containing the line of
///     source code where the exception was thrown; and <c>url</c>, a string containing the name of
///     the script file containing the code that threw the exception.
///     </para>
///     <para>
///     Requires an active script context.
///     </para>
/// </remarks>
/// <param name="metadata">The exception metadata for the runtime of the current context.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsGetAndClearExceptionWithMetadata(var metadata: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsGetAndClearExceptionWithMetadata' {$ENDIF};

/// <summary>
///     Called by the runtime to load the source code of the serialized script.
/// </summary>
/// <param name="sourceContext">The context passed to Js[Parse|Run]SerializedScriptCallback</param>
/// <param name="script">The script returned.</param>
/// <returns>
///     true if the operation succeeded, false otherwise.
/// </returns>
type
  JsSerializedLoadScriptCallback = function(sourceContext: JsSourceContext; var value: JsValueRef;  var parseAttributes: JsParseScriptAttributes): boolean; stdcall;

/// <summary>
///     Create JavascriptString variable from ASCII or Utf8 string
/// </summary>
/// <remarks>
///     <para>
///        Requires an active script context.
///     </para>
///     <para>
///         Input string can be either ASCII or Utf8
///     </para>
/// </remarks>
/// <param name="content">Pointer to string memory.</param>
/// <param name="length">Number of bytes within the string</param>
/// <param name="value">JsValueRef representing the JavascriptString</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCreateString(content: PAnsiChar; length: NativeUInt; var value: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCreateString' {$ENDIF};

/// <summary>
///     Create JavascriptString variable from Utf16 string
/// </summary>
/// <remarks>
///     <para>
///        Requires an active script context.
///     </para>
///     <para>
///         Expects Utf16 string
///     </para>
/// </remarks>
/// <param name="content">Pointer to string memory.</param>
/// <param name="length">Number of characters within the string</param>
/// <param name="value">JsValueRef representing the JavascriptString</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCreateStringUtf16(content: PWideChar; length: NativeUInt; var value: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCreateStringUtf16' {$ENDIF};

/// <summary>
///     Write JavascriptString value into C string buffer (Utf8)
/// </summary>
/// <remarks>
///     <para>
///         When size of the `buffer` is unknown,
///         `buffer` argument can be nullptr.
///         In that case, `length` argument will return the length needed.
///     </para>
/// </remarks>
/// <param name="value">JavascriptString value</param>
/// <param name="buffer">Pointer to buffer</param>
/// <param name="bufferSize">Buffer size</param>
/// <param name="length">Total number of characters needed or written</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCopyString(value: JsValueRef; var buffer: PAnsiChar; bufferSize: NativeUInt; var length: NativeUInt): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCopyString' {$ENDIF};

/// <summary>
///     Write string value into Utf16 string buffer
/// </summary>
/// <remarks>
///     <para>
///         When size of the `buffer` is unknown,
///         `buffer` argument can be nullptr.
///         In that case, `written` argument will return the length needed.
///     </para>
///     <para>
///         when start is out of range or &lt; 0, returns JsErrorInvalidArgument
///         and `written` will be equal to 0.
///         If calculated length is 0 (It can be due to string length or `start`
///         and length combination), then `written` will be equal to 0 and call
///         returns JsNoError
///     </para>
/// </remarks>
/// <param name="value">JavascriptString value</param>
/// <param name="start">start offset of buffer</param>
/// <param name="length">length to be written</param>
/// <param name="buffer">Pointer to buffer</param>
/// <param name="written">Total number of characters written</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCopyStringUtf16(value: JsValueRef; start: integer; length: integer; var buffer: PWideChar; var written: NativeUInt): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCopyStringUtf16' {$ENDIF};

/// <summary>
///     Parses a script and returns a function representing the script.
/// </summary>
/// <remarks>
///     <para>
///        Requires an active script context.
///     </para>
///     <para>
///         Script source can be either JavascriptString or JavascriptExternalArrayBuffer.
///         In case it is an ExternalArrayBuffer, and the encoding of the buffer is Utf16,
///         JsParseScriptAttributeArrayBufferIsUtf16Encoded is expected on parseAttributes.
///     </para>
///     <para>
///         Use JavascriptExternalArrayBuffer with Utf8/ASCII script source
///         for better performance and smaller memory footprint.
///     </para>
/// </remarks>
/// <param name="script">The script to run.</param>
/// <param name="sourceContext">
///     A cookie identifying the script that can be used by debuggable script contexts.
/// </param>
/// <param name="sourceUrl">The location the script came from.</param>
/// <param name="parseAttributes">Attribute mask for parsing the script</param>
/// <param name="result">The result of the compiled script.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsParse(script: JsValueRef; sourceContext: JsSourceContext; sourceUrl: JsValueRef; parseAttributes: JsParseScriptAttributes; var result: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsParse' {$ENDIF};

/// <summary>
///     Executes a script.
/// </summary>
/// <remarks>
///     <para>
///        Requires an active script context.
///     </para>
///     <para>
///         Script source can be either JavascriptString or JavascriptExternalArrayBuffer.
///         In case it is an ExternalArrayBuffer, and the encoding of the buffer is Utf16,
///         JsParseScriptAttributeArrayBufferIsUtf16Encoded is expected on parseAttributes.
///     </para>
///     <para>
///         Use JavascriptExternalArrayBuffer with Utf8/ASCII script source
///         for better performance and smaller memory footprint.
///     </para>
/// </remarks>
/// <param name="script">The script to run.</param>
/// <param name="sourceContext">
///     A cookie identifying the script that can be used by debuggable script contexts.
/// </param>
/// <param name="sourceUrl">The location the script came from</param>
/// <param name="parseAttributes">Attribute mask for parsing the script</param>
/// <param name="result">The result of the script, if any. This parameter can be null.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsRun(script: JsValueRef; sourceContext: JsSourceContext; sourceUrl: JsValueRef; parseAttributes: JsParseScriptAttributes; var result: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsRun' {$ENDIF};

/// <summary>
///     Creates the property ID associated with the name.
/// </summary>
/// <remarks>
///     <para>
///         Property IDs are specific to a context and cannot be used across contexts.
///     </para>
///     <para>
///         Requires an active script context.
///     </para>
/// </remarks>
/// <param name="name">
///     The name of the property ID to get or create. The name may consist of only digits.
///     The string is expected to be ASCII / utf8 encoded.
/// </param>
/// <param name="length">length of the name in bytes</param>
/// <param name="propertyId">The property ID in this runtime for the given name.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCreatePropertyId(const name: PAnsiChar; length: NativeUInt; var propertyId: JsPropertyIdRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCreatePropertyId' {$ENDIF};

/// <summary>
///     Copies the name associated with the property ID into a buffer.
/// </summary>
/// <remarks>
///     <para>
///         Requires an active script context.
///     </para>
///     <para>
///         When size of the `buffer` is unknown,
///         `buffer` argument can be nullptr.
///         `length` argument will return the size needed.
///     </para>
/// </remarks>
/// <param name="propertyId">The property ID to get the name of.</param>
/// <param name="buffer">The buffer holding the name associated with the property ID, encoded as utf8</param>
/// <param name="bufferSize">Size of the buffer.</param>
/// <param name="written">Total number of characters written or to be written</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCopyPropertyId(propertyId: JsPropertyIdRef; var buffer: PByte; bufferSize: NativeUInt; var length: NativeUInt): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCopyPropertyId' {$ENDIF};

/// <summary>
///     Serializes a parsed script to a buffer than can be reused.
/// </summary>
/// <remarks>
///     <para>
///     <c>JsSerializeScript</c> parses a script and then stores the parsed form of the script in a
///     runtime-independent format. The serialized script then can be deserialized in any
///     runtime without requiring the script to be re-parsed.
///     </para>
///     <para>
///     Requires an active script context.
///     </para>
///     <para>
///         Script source can be either JavascriptString or JavascriptExternalArrayBuffer.
///         In case it is an ExternalArrayBuffer, and the encoding of the buffer is Utf16,
///         JsParseScriptAttributeArrayBufferIsUtf16Encoded is expected on parseAttributes.
///     </para>
///     <para>
///         Use JavascriptExternalArrayBuffer with Utf8/ASCII script source
///         for better performance and smaller memory footprint.
///     </para>
/// </remarks>
/// <param name="script">The script to serialize</param>
/// <param name="buffer">ArrayBuffer</param>
/// <param name="parseAttributes">Encoding for the script.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsSerialize(script: JsValueRef; var buffer: JsValueRef; parseAttributes: JsParseScriptAttributes): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsSerialize' {$ENDIF};

/// <summary>
///     Parses a serialized script and returns a function representing the script.
///     Provides the ability to lazy load the script source only if/when it is needed.
/// </summary>
/// <remarks>
///     <para>
///     Requires an active script context.
///     </para>
/// </remarks>
/// <param name="buffer">The serialized script as an ArrayBuffer (preferably ExternalArrayBuffer).</param>
/// <param name="scriptLoadCallback">
///     Callback called when the source code of the script needs to be loaded.
///     This is an optional parameter, set to null if not needed.
/// </param>
/// <param name="sourceContext">
///     A cookie identifying the script that can be used by debuggable script contexts.
///     This context will passed into scriptLoadCallback.
/// </param>
/// <param name="sourceUrl">The location the script came from.</param>
/// <param name="result">A function representing the script code.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsParseSerialized(buffer: JsValueRef; scriptLoadCallback: JsSerializedLoadScriptCallback; sourceContext: JsSourceContext; sourceUrl: JsValueRef; var result: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsParseSerialized' {$ENDIF};

/// <summary>
///     Runs a serialized script.
///     Provides the ability to lazy load the script source only if/when it is needed.
/// </summary>
/// <remarks>
///     <para>
///     Requires an active script context.
///     </para>
///     <para>
///     The runtime will hold on to the buffer until all instances of any functions created from
///     the buffer are garbage collected.
///     </para>
/// </remarks>
/// <param name="buffer">The serialized script as an ArrayBuffer (preferably ExternalArrayBuffer).</param>
/// <param name="scriptLoadCallback">Callback called when the source code of the script needs to be loaded.</param>
/// <param name="sourceContext">
///     A cookie identifying the script that can be used by debuggable script contexts.
///     This context will passed into scriptLoadCallback.
/// </param>
/// <param name="sourceUrl">The location the script came from.</param>
/// <param name="result">
///     The result of running the script, if any. This parameter can be null.
/// </param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsRunSerialized(buffer: JsValueRef; scriptLoadCallback: JsSerializedLoadScriptCallback; sourceContext: JsSourceContext; sourceUrl: JsValueRef; var result: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsRunSerialized' {$ENDIF};

/// <summary>
///     Creates a new JavaScript Promise object.
/// </summary>
/// <remarks>
///     Requires an active script context.
/// </remarks>
/// <param name="promise">The new Promise object.</param>
/// <param name="resolveFunction">The function called to resolve the created Promise object.</param>
/// <param name="rejectFunction">The function called to reject the created Promise object.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCreatePromise(var promise: JsValueRef; var resolveFunction: JsValueRef; var rejectFunction: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCreatePromise' {$ENDIF};

/// <summary>
///     A weak reference to a JavaScript value.
/// </summary>
/// <remarks>
///     A value with only weak references is available for garbage-collection. A strong reference
///     to the value (<c>JsValueRef</c>) may be obtained from a weak reference if the value happens
///     to still be available.
/// </remarks>
type
  JsWeakRef = JsRef;

/// <summary>
///     Creates a weak reference to a value.
/// </summary>
/// <param name="value">The value to be referenced.</param>
/// <param name="weakRef">Weak reference to the value.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCreateWeakReference(value: JsValueRef; var weakRef: JsWeakRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCreateWeakReference' {$ENDIF};

/// <summary>
///     Gets a strong reference to the value referred to by a weak reference.
/// </summary>
/// <param name="weakRef">A weak reference.</param>
/// <param name="value">Reference to the value, or <c>JS_INVALID_REFERENCE</c> if the value is
///     no longer available.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsGetWeakReferenceValue(weakRef: JsWeakRef; var value: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsGetWeakReferenceValue' {$ENDIF};

/// <summary>
///     Creates a Javascript SharedArrayBuffer object with shared content get from JsGetSharedArrayBufferContent.
/// </summary>
/// <remarks>
///     Requires an active script context.
/// </remarks>
/// <param name="sharedContents">
///     The storage object of a SharedArrayBuffer which can be shared between multiple thread.
/// </param>
/// <param name="result">The new SharedArrayBuffer object.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCreateSharedArrayBufferWithSharedContent(sharedContents: JsSharedArrayBufferContentHandle; var result: JsValueRef): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCreateSharedArrayBufferWithSharedContent' {$ENDIF};

/// <summary>
///     Get the storage object from a SharedArrayBuffer.
/// </summary>
/// <remarks>
///     Requires an active script context.
/// </remarks>
/// <param name="sharedArrayBuffer">The SharedArrayBuffer object.</param>
/// <param name="sharedContents">
///     The storage object of a SharedArrayBuffer which can be shared between multiple thread.
///     User should call JsReleaseSharedArrayBufferContentHandle after finished using it.
/// </param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsGetSharedArrayBufferContent(sharedArrayBuffer: JsValueRef; var sharedContents: JsSharedArrayBufferContentHandle): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsGetSharedArrayBufferContent' {$ENDIF};

/// <summary>
///     Decrease the reference count on a SharedArrayBuffer storage object.
/// </summary>
/// <remarks>
///     Requires an active script context.
/// </remarks>
/// <param name="sharedContents">
///     The storage object of a SharedArrayBuffer which can be shared between multiple thread.
/// </param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsReleaseSharedArrayBufferContentHandle(sharedContents: JsSharedArrayBufferContentHandle): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsReleaseSharedArrayBufferContentHandle' {$ENDIF};

/// <summary>
///     Determines whether an object has a non-inherited property.
/// </summary>
/// <remarks>
///     Requires an active script context.
/// </remarks>
/// <param name="object">The object that may contain the property.</param>
/// <param name="propertyId">The ID of the property.</param>
/// <param name="hasOwnProperty">Whether the object has the non-inherited property.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsHasOwnProperty(obj: JsValueRef; propertyId: JsPropertyIdRef; var hasOwnProperty: boolean): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsHasOwnProperty' {$ENDIF};

/// <summary>
///     Write JS string value into char string buffer without a null terminator
/// </summary>
/// <remarks>
///     <para>
///         When size of the `buffer` is unknown,
///         `buffer` argument can be nullptr.
///         In that case, `written` argument will return the length needed.
///     </para>
///     <para>
///         When start is out of range or &lt; 0, returns JsErrorInvalidArgument
///         and `written` will be equal to 0.
///         If calculated length is 0 (It can be due to string length or `start`
///         and length combination), then `written` will be equal to 0 and call
///         returns JsNoError
///     </para>
///     <para>
///         The JS string `value` will be converted one utf16 code point at a time,
///         and if it has code points that do not fit in one byte, those values
///         will be truncated.
///     </para>
/// </remarks>
/// <param name="value">JavascriptString value</param>
/// <param name="start">Start offset of buffer</param>
/// <param name="length">Number of characters to be written</param>
/// <param name="buffer">Pointer to buffer</param>
/// <param name="written">Total number of characters written</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsCopyStringOneByte(value: JsValueRef; start: integer; length: integer; buffer: PAnsiChar; var written: NativeUInt): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsCopyStringOneByte' {$ENDIF};

/// <summary>
///     Obtains frequently used properties of a data view.
/// </summary>
/// <param name="dataView">The data view instance.</param>
/// <param name="arrayBuffer">The ArrayBuffer backstore of the view.</param>
/// <param name="byteOffset">The offset in bytes from the start of arrayBuffer referenced by the array.</param>
/// <param name="byteLength">The number of bytes in the array.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsGetDataViewInfo(dataView: JsValueRef;  var arrayBuffer: JsValueRef; var byteOffset: cardinal; var byteLength: cardinal): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsGetDataViewInfo' {$ENDIF};

/// <summary>
///     Determine if one JavaScript value is less than another JavaScript value.
/// </summary>
/// <remarks>
///     <para>
///     This function is equivalent to the <c>&lt;</c> operator in Javascript.
///     </para>
///     <para>
///     Requires an active script context.
///     </para>
/// </remarks>
/// <param name="object1">The first object to compare.</param>
/// <param name="object2">The second object to compare.</param>
/// <param name="result">Whether object1 is less than object2.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsLessThan(object1: JsValueRef; object2: JsValueRef; var result: boolean): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsLessThan' {$ENDIF};

/// <summary>
///     Determine if one JavaScript value is less than or equal to another JavaScript value.
/// </summary>
/// <remarks>
///     <para>
///     This function is equivalent to the <c>&lt;=</c> operator in Javascript.
///     </para>
///     <para>
///     Requires an active script context.
///     </para>
/// </remarks>
/// <param name="object1">The first object to compare.</param>
/// <param name="object2">The second object to compare.</param>
/// <param name="result">Whether object1 is less than or equal to object2.</param>
/// <returns>
///     The code <c>JsNoError</c> if the operation succeeded, a failure code otherwise.
/// </returns>
function JsLessThanOrEqual(object1: JsValueRef; object2: JsValueRef; var result: boolean): JsErrorCode;
  stdcall; external CHAKRA_LIB {$IFDEF MACOS} name '_JsLessThanOrEqual' {$ENDIF};

implementation

end.
