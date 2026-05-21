// Compiles a dart2wasm-generated main module from `source` which can then
// instantiatable via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm modules from `bytes` which is then
// instantiatable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export async function instantiate(modulePromise, importObjectPromise) {
  var moduleOrCompiledApp = await modulePromise;
  if (!(moduleOrCompiledApp instanceof CompiledApp)) {
    moduleOrCompiledApp = new CompiledApp(moduleOrCompiledApp);
  }
  const instantiatedApp = await moduleOrCompiledApp.instantiate(await importObjectPromise);
  return instantiatedApp.instantiatedModule;
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export const invoke = (moduleInstance, ...args) => {
  moduleInstance.exports.$invokeMain(args);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arugments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `load-ids` option is passed. Each load ID maps to one
  //   or more wasm files as specified in the emitted JSON file. It also takes a
  //   callback that should be invoked for each loaded module with 2 arugments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDynamicModule` is a JS function that takes two string names matching,
  //   in order, a wasm file produced by the dart2wasm compiler during dynamic
  //   module compilation and a corresponding js file produced by the same
  //   compilation. It also takes a callback that should be invoked with the
  //   loaded module in a format supported by `WebAssembly.compile` or
  //   `WebAssembly.compileStreaming` and the result of using the JS 'import'
  //   API on the js file path. It should return a Promise that resolves when
  //   all the modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports,
      {loadDeferredModules, loadDynamicModule, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            _1: (decoder, codeUnits) => decoder.decode(codeUnits),
      _2: () => new TextDecoder("utf-8", {fatal: true}),
      _3: () => new TextDecoder("utf-8", {fatal: false}),
      _4: (s) => +s,
      _5: x0 => new Uint8Array(x0),
      _6: (x0,x1,x2) => x0.set(x1,x2),
      _7: (x0,x1) => x0.transferFromImageBitmap(x1),
      _9: (x0,x1,x2) => x0.slice(x1,x2),
      _10: (x0,x1) => x0.decode(x1),
      _11: (x0,x1) => x0.segment(x1),
      _12: () => new TextDecoder(),
      _14: x0 => x0.buffer,
      _15: x0 => x0.wasmMemory,
      _16: () => globalThis.window._flutter_skwasmInstance,
      _17: x0 => x0.rasterStartMilliseconds,
      _18: x0 => x0.rasterEndMilliseconds,
      _19: x0 => x0.imageBitmaps,
      _135: (x0,x1) => x0.appendChild(x1),
      _166: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _167: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _168: (x0,x1) => new OffscreenCanvas(x0,x1),
      _169: x0 => x0.remove(),
      _170: (x0,x1) => x0.append(x1),
      _172: x0 => x0.unlock(),
      _173: x0 => x0.getReader(),
      _174: (x0,x1) => x0.item(x1),
      _175: x0 => x0.next(),
      _176: x0 => x0.now(),
      _177: (x0,x1) => x0.revokeObjectURL(x1),
      _178: x0 => x0.close(),
      _179: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      _180: x0 => new window.ImageDecoder(x0),
      _181: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      _182: (x0,x1) => x0.decode(x1),
      _183: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._183(f,arguments.length,x0) }),
      _184: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _186: (x0,x1) => x0.getModifierState(x1),
      _187: x0 => x0.preventDefault(),
      _188: x0 => x0.stopPropagation(),
      _189: (x0,x1) => x0.removeProperty(x1),
      _190: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._190(f,arguments.length,x0) }),
      _191: x0 => new window.FinalizationRegistry(x0),
      _192: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      _194: (x0,x1) => x0.unregister(x1),
      _195: (x0,x1) => x0.prepend(x1),
      _196: x0 => new Intl.Locale(x0),
      _197: (x0,x1) => x0.observe(x1),
      _198: x0 => x0.disconnect(),
      _199: (x0,x1) => x0.getAttribute(x1),
      _200: (x0,x1) => x0.contains(x1),
      _201: (x0,x1) => x0.querySelector(x1),
      _202: (x0,x1) => x0.matchMedia(x1),
      _203: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._203(f,arguments.length,x0) }),
      _204: (x0,x1,x2) => x0.call(x1,x2),
      _205: x0 => x0.blur(),
      _206: x0 => x0.hasFocus(),
      _207: (x0,x1) => x0.removeAttribute(x1),
      _208: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _209: (x0,x1) => x0.hasAttribute(x1),
      _210: (x0,x1) => x0.getModifierState(x1),
      _211: (x0,x1) => x0.createTextNode(x1),
      _212: x0 => x0.getBoundingClientRect(),
      _213: (x0,x1) => x0.replaceWith(x1),
      _214: (x0,x1) => x0.contains(x1),
      _215: (x0,x1) => x0.closest(x1),
      _653: x0 => new Uint8Array(x0),
      _656: () => globalThis.window.flutterConfiguration,
      _658: x0 => x0.assetBase,
      _663: x0 => x0.canvasKitMaximumSurfaces,
      _664: x0 => x0.debugShowSemanticsNodes,
      _665: x0 => x0.hostElement,
      _666: x0 => x0.multiViewEnabled,
      _667: x0 => x0.nonce,
      _669: x0 => x0.fontFallbackBaseUrl,
      _679: x0 => x0.console,
      _680: x0 => x0.devicePixelRatio,
      _681: x0 => x0.document,
      _682: x0 => x0.history,
      _683: x0 => x0.innerHeight,
      _684: x0 => x0.innerWidth,
      _685: x0 => x0.location,
      _686: x0 => x0.navigator,
      _687: x0 => x0.visualViewport,
      _688: x0 => x0.performance,
      _689: x0 => x0.parent,
      _691: x0 => x0.URL,
      _693: (x0,x1) => x0.getComputedStyle(x1),
      _694: x0 => x0.screen,
      _695: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._695(f,arguments.length,x0) }),
      _696: (x0,x1) => x0.requestAnimationFrame(x1),
      _700: (x0,x1) => x0.warn(x1),
      _702: (x0,x1) => x0.debug(x1),
      _703: x0 => globalThis.parseFloat(x0),
      _704: () => globalThis.window,
      _705: () => globalThis.Intl,
      _706: () => globalThis.Symbol,
      _707: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      _709: x0 => x0.clipboard,
      _710: x0 => x0.maxTouchPoints,
      _711: x0 => x0.vendor,
      _712: x0 => x0.language,
      _713: x0 => x0.platform,
      _714: x0 => x0.userAgent,
      _715: (x0,x1) => x0.vibrate(x1),
      _716: x0 => x0.languages,
      _717: x0 => x0.documentElement,
      _718: (x0,x1) => x0.querySelector(x1),
      _719: (x0,x1) => x0.querySelectorAll(x1),
      _721: (x0,x1) => x0.createElement(x1),
      _724: (x0,x1) => x0.createEvent(x1),
      _725: x0 => x0.activeElement,
      _728: x0 => x0.head,
      _729: x0 => x0.body,
      _731: (x0,x1) => { x0.title = x1 },
      _734: x0 => x0.visibilityState,
      _735: () => globalThis.document,
      _736: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._736(f,arguments.length,x0) }),
      _737: (x0,x1) => x0.dispatchEvent(x1),
      _745: x0 => x0.target,
      _747: x0 => x0.timeStamp,
      _748: x0 => x0.type,
      _750: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      _757: x0 => x0.firstChild,
      _761: x0 => x0.parentElement,
      _763: (x0,x1) => { x0.textContent = x1 },
      _764: x0 => x0.parentNode,
      _765: x0 => x0.nextSibling,
      _766: (x0,x1) => x0.removeChild(x1),
      _767: x0 => x0.isConnected,
      _775: x0 => x0.clientHeight,
      _776: x0 => x0.clientWidth,
      _777: x0 => x0.offsetHeight,
      _778: x0 => x0.offsetWidth,
      _779: x0 => x0.id,
      _780: (x0,x1) => { x0.id = x1 },
      _783: (x0,x1) => { x0.spellcheck = x1 },
      _784: x0 => x0.tagName,
      _785: x0 => x0.style,
      _787: (x0,x1) => x0.querySelectorAll(x1),
      _788: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _789: x0 => x0.tabIndex,
      _790: (x0,x1) => { x0.tabIndex = x1 },
      _791: (x0,x1) => x0.focus(x1),
      _792: x0 => x0.scrollTop,
      _793: (x0,x1) => { x0.scrollTop = x1 },
      _794: (x0,x1) => { x0.scrollLeft = x1 },
      _795: x0 => x0.scrollLeft,
      _796: x0 => x0.classList,
      _797: (x0,x1) => x0.scrollIntoView(x1),
      _800: (x0,x1) => { x0.className = x1 },
      _802: (x0,x1) => x0.getElementsByClassName(x1),
      _803: x0 => x0.click(),
      _804: (x0,x1) => x0.attachShadow(x1),
      _807: x0 => x0.computedStyleMap(),
      _808: (x0,x1) => x0.get(x1),
      _814: (x0,x1) => x0.getPropertyValue(x1),
      _815: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      _816: x0 => x0.offsetLeft,
      _817: x0 => x0.offsetTop,
      _818: x0 => x0.offsetParent,
      _820: (x0,x1) => { x0.name = x1 },
      _821: x0 => x0.content,
      _822: (x0,x1) => { x0.content = x1 },
      _826: (x0,x1) => { x0.src = x1 },
      _827: x0 => x0.naturalWidth,
      _828: x0 => x0.naturalHeight,
      _832: (x0,x1) => { x0.crossOrigin = x1 },
      _834: (x0,x1) => { x0.decoding = x1 },
      _835: x0 => x0.decode(),
      _840: (x0,x1) => { x0.nonce = x1 },
      _845: (x0,x1) => { x0.width = x1 },
      _847: (x0,x1) => { x0.height = x1 },
      _850: (x0,x1) => x0.getContext(x1),
      _918: x0 => x0.width,
      _919: x0 => x0.height,
      _921: (x0,x1) => x0.fetch(x1),
      _922: x0 => x0.status,
      _924: x0 => x0.body,
      _925: x0 => x0.arrayBuffer(),
      _928: x0 => x0.read(),
      _929: x0 => x0.value,
      _930: x0 => x0.done,
      _937: x0 => x0.name,
      _938: x0 => x0.x,
      _939: x0 => x0.y,
      _942: x0 => x0.top,
      _943: x0 => x0.right,
      _944: x0 => x0.bottom,
      _945: x0 => x0.left,
      _955: x0 => x0.height,
      _956: x0 => x0.width,
      _957: x0 => x0.scale,
      _958: (x0,x1) => { x0.value = x1 },
      _961: (x0,x1) => { x0.placeholder = x1 },
      _963: (x0,x1) => { x0.name = x1 },
      _964: x0 => x0.selectionDirection,
      _965: x0 => x0.selectionStart,
      _966: x0 => x0.selectionEnd,
      _969: x0 => x0.value,
      _971: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _972: x0 => x0.readText(),
      _973: (x0,x1) => x0.writeText(x1),
      _975: x0 => x0.altKey,
      _976: x0 => x0.code,
      _977: x0 => x0.ctrlKey,
      _978: x0 => x0.key,
      _979: x0 => x0.keyCode,
      _980: x0 => x0.location,
      _981: x0 => x0.metaKey,
      _982: x0 => x0.repeat,
      _983: x0 => x0.shiftKey,
      _984: x0 => x0.isComposing,
      _986: x0 => x0.state,
      _987: (x0,x1) => x0.go(x1),
      _989: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      _990: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      _991: x0 => x0.pathname,
      _992: x0 => x0.search,
      _993: x0 => x0.hash,
      _997: x0 => x0.state,
      _1000: (x0,x1) => x0.createObjectURL(x1),
      _1002: x0 => new Blob(x0),
      _1012: x0 => x0.matches,
      _1016: x0 => x0.matches,
      _1020: x0 => x0.relatedTarget,
      _1022: x0 => x0.clientX,
      _1023: x0 => x0.clientY,
      _1024: x0 => x0.offsetX,
      _1025: x0 => x0.offsetY,
      _1028: x0 => x0.button,
      _1029: x0 => x0.buttons,
      _1030: x0 => x0.ctrlKey,
      _1034: x0 => x0.pointerId,
      _1035: x0 => x0.pointerType,
      _1036: x0 => x0.pressure,
      _1037: x0 => x0.tiltX,
      _1038: x0 => x0.tiltY,
      _1039: x0 => x0.getCoalescedEvents(),
      _1042: x0 => x0.deltaX,
      _1043: x0 => x0.deltaY,
      _1044: x0 => x0.wheelDeltaX,
      _1045: x0 => x0.wheelDeltaY,
      _1046: x0 => x0.deltaMode,
      _1053: x0 => x0.changedTouches,
      _1056: x0 => x0.clientX,
      _1057: x0 => x0.clientY,
      _1060: x0 => x0.data,
      _1063: (x0,x1) => { x0.disabled = x1 },
      _1065: (x0,x1) => { x0.type = x1 },
      _1066: (x0,x1) => { x0.max = x1 },
      _1067: (x0,x1) => { x0.min = x1 },
      _1068: x0 => x0.value,
      _1069: (x0,x1) => { x0.value = x1 },
      _1070: x0 => x0.disabled,
      _1071: (x0,x1) => { x0.disabled = x1 },
      _1073: (x0,x1) => { x0.placeholder = x1 },
      _1075: (x0,x1) => { x0.name = x1 },
      _1076: (x0,x1) => { x0.autocomplete = x1 },
      _1078: x0 => x0.selectionDirection,
      _1079: x0 => x0.selectionStart,
      _1081: x0 => x0.selectionEnd,
      _1084: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _1085: (x0,x1) => x0.add(x1),
      _1087: (x0,x1) => { x0.noValidate = x1 },
      _1088: (x0,x1) => { x0.method = x1 },
      _1089: (x0,x1) => { x0.action = x1 },
      _1114: x0 => x0.orientation,
      _1115: x0 => x0.width,
      _1116: x0 => x0.height,
      _1117: (x0,x1) => x0.lock(x1),
      _1136: x0 => new ResizeObserver(x0),
      _1139: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1139(f,arguments.length,x0,x1) }),
      _1147: x0 => x0.length,
      _1148: x0 => x0.iterator,
      _1149: x0 => x0.Segmenter,
      _1150: x0 => x0.v8BreakIterator,
      _1151: (x0,x1) => new Intl.Segmenter(x0,x1),
      _1154: x0 => x0.language,
      _1155: x0 => x0.script,
      _1156: x0 => x0.region,
      _1174: x0 => x0.done,
      _1175: x0 => x0.value,
      _1176: x0 => x0.index,
      _1180: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      _1181: (x0,x1) => x0.adoptText(x1),
      _1182: x0 => x0.first(),
      _1183: x0 => x0.next(),
      _1184: x0 => x0.current(),
      _1186: () => globalThis.window.FinalizationRegistry,
      _1197: x0 => x0.hostElement,
      _1198: x0 => x0.viewConstraints,
      _1201: x0 => x0.maxHeight,
      _1202: x0 => x0.maxWidth,
      _1203: x0 => x0.minHeight,
      _1204: x0 => x0.minWidth,
      _1205: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1205(f,arguments.length,x0) }),
      _1206: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1206(f,arguments.length,x0) }),
      _1207: (x0,x1) => ({addView: x0,removeView: x1}),
      _1210: x0 => x0.loader,
      _1211: () => globalThis._flutter,
      _1212: (x0,x1) => x0.didCreateEngineInitializer(x1),
      _1213: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1213(f,arguments.length,x0) }),
      _1214: (module,f) => finalizeWrapper(f, function() { return module.exports._1214(f,arguments.length) }),
      _1215: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      _1218: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1218(f,arguments.length,x0) }),
      _1219: x0 => ({runApp: x0}),
      _1221: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1221(f,arguments.length,x0,x1) }),
      _1222: x0 => new Promise(x0),
      _1223: x0 => x0.length,
      _1224: () => globalThis.window.ImageDecoder,
      _1225: x0 => x0.tracks,
      _1227: x0 => x0.completed,
      _1229: x0 => x0.image,
      _1235: x0 => x0.displayWidth,
      _1236: x0 => x0.displayHeight,
      _1237: x0 => x0.duration,
      _1240: x0 => x0.ready,
      _1241: x0 => x0.selectedTrack,
      _1242: x0 => x0.repetitionCount,
      _1243: x0 => x0.frameCount,
      _1285: (x0,x1) => x0.createElement(x1),
      _1286: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1286(f,arguments.length,x0) }),
      _1287: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1288: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _1289: x0 => x0.exitFullscreen(),
      _1290: x0 => x0.requestFullscreen(),
      _1296: (x0,x1) => x0.createElement(x1),
      _1302: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _1303: x0 => x0.load(),
      _1304: x0 => x0.play(),
      _1305: x0 => x0.pause(),
      _1308: (x0,x1) => x0.removeAttribute(x1),
      _1309: (x0,x1) => x0.start(x1),
      _1310: (x0,x1) => x0.end(x1),
      _1311: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _1312: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      _1318: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1319: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1319(f,arguments.length,x0) }),
      _1320: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1320(f,arguments.length,x0) }),
      _1321: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1321(f,arguments.length,x0) }),
      _1322: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1322(f,arguments.length,x0) }),
      _1323: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1323(f,arguments.length,x0) }),
      _1324: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1324(f,arguments.length,x0) }),
      _1325: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1325(f,arguments.length,x0) }),
      _1326: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1326(f,arguments.length,x0) }),
      _1327: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1327(f,arguments.length,x0) }),
      _1328: (x0,x1) => x0.setSinkId(x1),
      _1329: x0 => x0.decode(),
      _1330: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1331: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      _1332: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1332(f,arguments.length,x0) }),
      _1333: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1333(f,arguments.length,x0) }),
      _1334: x0 => x0.send(),
      _1335: () => new XMLHttpRequest(),
      _1336: (x0,x1) => x0.getItem(x1),
      _1337: (x0,x1) => x0.removeItem(x1),
      _1338: (x0,x1,x2) => x0.setItem(x1,x2),
      _1339: (x0,x1) => x0.querySelector(x1),
      _1340: (x0,x1) => x0.item(x1),
      _1341: () => new FileReader(),
      _1343: (x0,x1) => x0.readAsArrayBuffer(x1),
      _1344: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1344(f,arguments.length,x0) }),
      _1345: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1345(f,arguments.length,x0) }),
      _1346: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1346(f,arguments.length,x0) }),
      _1347: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1347(f,arguments.length,x0) }),
      _1348: (x0,x1) => x0.removeChild(x1),
      _1349: x0 => x0.click(),
      _1353: Date.now,
      _1355: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _1356: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _1357: () => typeof dartUseDateNowForTicks !== "undefined",
      _1358: () => 1000 * performance.now(),
      _1359: () => Date.now(),
      _1360: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      _1361: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      _1362: () => new WeakMap(),
      _1363: (map, o) => map.get(o),
      _1364: (map, o, v) => map.set(o, v),
      _1365: x0 => new WeakRef(x0),
      _1366: x0 => x0.deref(),
      _1373: () => globalThis.WeakRef,
      _1377: s => JSON.stringify(s),
      _1378: s => printToConsole(s),
      _1379: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      _1380: (o, p, r) => o.replaceAll(p, () => r),
      _1381: (o, p, r) => o.replace(p, () => r),
      _1382: Function.prototype.call.bind(String.prototype.toLowerCase),
      _1383: s => s.toUpperCase(),
      _1384: s => s.trim(),
      _1385: s => s.trimLeft(),
      _1386: s => s.trimRight(),
      _1387: (string, times) => string.repeat(times),
      _1388: Function.prototype.call.bind(String.prototype.indexOf),
      _1389: (s, p, i) => s.lastIndexOf(p, i),
      _1390: (string, token) => string.split(token),
      _1391: Object.is,
      _1396: (o, c) => o instanceof c,
      _1397: o => Object.keys(o),
      _1399: (o) => {
        const typeofValue = typeof o;
        return (typeofValue === 'object') ||
            typeofValue === 'function';
      },
      _1401: (o, a) => o + a,
      _1451: x0 => new Array(x0),
      _1453: x0 => x0.length,
      _1455: (x0,x1) => x0[x1],
      _1456: (x0,x1,x2) => { x0[x1] = x2 },
      _1459: (x0,x1,x2) => new DataView(x0,x1,x2),
      _1461: x0 => new Int8Array(x0),
      _1462: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      _1464: x0 => new Uint8ClampedArray(x0),
      _1466: x0 => new Int16Array(x0),
      _1468: x0 => new Uint16Array(x0),
      _1470: x0 => new Int32Array(x0),
      _1472: x0 => new Uint32Array(x0),
      _1474: x0 => new Float32Array(x0),
      _1476: x0 => new Float64Array(x0),
      _1500: x0 => x0.random(),
      _1501: (x0,x1) => x0.getRandomValues(x1),
      _1502: () => globalThis.crypto,
      _1503: () => globalThis.Math,
      _1505: () => globalThis.performance,
      _1506: () => globalThis.JSON,
      _1507: x0 => x0.measure,
      _1508: x0 => x0.mark,
      _1509: x0 => x0.clearMeasures,
      _1510: x0 => x0.clearMarks,
      _1511: (x0,x1,x2,x3) => x0.measure(x1,x2,x3),
      _1512: (x0,x1,x2) => x0.mark(x1,x2),
      _1513: x0 => x0.clearMeasures(),
      _1514: x0 => x0.clearMarks(),
      _1515: (x0,x1) => x0.parse(x1),
      _1516: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _1517: (handle) => clearTimeout(handle),
      _1518: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _1519: (handle) => clearInterval(handle),
      _1520: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _1521: () => Date.now(),
      _1522: () => new Error().stack,
      _1523: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _1524: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _1525: (x0,x1) => x0.exec(x1),
      _1526: (x0,x1) => x0.test(x1),
      _1527: x0 => x0.pop(),
      _1529: o => o === undefined,
      _1531: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _1533: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _1534: o => o instanceof RegExp,
      _1535: (l, r) => l === r,
      _1536: o => o,
      _1537: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      _1538: o => o,
      _1539: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      _1540: o => o,
      _1541: b => !!b,
      _1542: o => o.length,
      _1544: (o, i) => o[i],
      _1545: f => f.dartFunction,
      _1546: () => ({}),
      _1547: () => [],
      _1549: () => globalThis,
      _1550: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _1551: (o, p) => p in o,
      _1552: (o, p) => o[p],
      _1553: (o, p, v) => o[p] = v,
      _1554: (o, m, a) => o[m].apply(o, a),
      _1556: o => String(o),
      _1557: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _1558: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1558(f,arguments.length,x0) }),
      _1559: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1559(f,arguments.length,x0,x1) }),
      _1560: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      _1561: o => [o],
      _1562: (o0, o1) => [o0, o1],
      _1563: (o0, o1, o2) => [o0, o1, o2],
      _1564: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _1565: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      _1566: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1567: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1568: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1569: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1570: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1571: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1572: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1573: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1574: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _1575: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _1576: x0 => new ArrayBuffer(x0),
      _1577: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _1579: x0 => x0.index,
      _1580: x0 => x0.groups,
      _1581: x0 => x0.flags,
      _1582: x0 => x0.multiline,
      _1583: x0 => x0.ignoreCase,
      _1584: x0 => x0.unicode,
      _1585: x0 => x0.dotAll,
      _1586: (x0,x1) => { x0.lastIndex = x1 },
      _1587: (o, p) => p in o,
      _1588: (o, p) => o[p],
      _1598: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1598(f,arguments.length,x0) }),
      _1610: () => new AbortController(),
      _1611: x0 => x0.abort(),
      _1612: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      _1613: (x0,x1) => globalThis.fetch(x0,x1),
      _1614: (x0,x1) => x0.get(x1),
      _1615: (module,f) => finalizeWrapper(f, function(x0,x1,x2) { return module.exports._1615(f,arguments.length,x0,x1,x2) }),
      _1616: (x0,x1) => x0.forEach(x1),
      _1617: x0 => x0.getReader(),
      _1618: x0 => x0.cancel(),
      _1619: x0 => x0.read(),
      _1623: (x0,x1) => x0.key(x1),
      _1624: o => o instanceof Array,
      _1625: (a, i) => a.splice(i, 1)[0],
      _1628: a => a.pop(),
      _1629: (a, i) => a.splice(i, 1),
      _1630: (a, s) => a.join(s),
      _1631: (a, s, e) => a.slice(s, e),
      _1633: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      _1634: a => a.length,
      _1636: (a, i) => a[i],
      _1637: (a, i, v) => a[i] = v,
      _1639: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      _1640: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _1642: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      _1643: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _1644: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      _1645: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _1646: o => o instanceof Uint8ClampedArray,
      _1647: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _1648: o => o instanceof Uint16Array,
      _1649: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _1650: o => o instanceof Int16Array,
      _1651: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _1652: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      _1653: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _1654: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      _1655: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _1657: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _1658: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      _1659: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _1660: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      _1661: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _1662: (a, i) => a.push(i),
      _1663: (t, s) => t.set(s),
      _1664: l => new DataView(new ArrayBuffer(l)),
      _1665: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _1666: o => o.byteLength,
      _1667: o => o.buffer,
      _1668: o => o.byteOffset,
      _1669: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _1670: (b, o) => new DataView(b, o),
      _1671: (b, o, l) => new DataView(b, o, l),
      _1672: Function.prototype.call.bind(DataView.prototype.getUint8),
      _1673: Function.prototype.call.bind(DataView.prototype.setUint8),
      _1674: Function.prototype.call.bind(DataView.prototype.getInt8),
      _1675: Function.prototype.call.bind(DataView.prototype.setInt8),
      _1676: Function.prototype.call.bind(DataView.prototype.getUint16),
      _1677: Function.prototype.call.bind(DataView.prototype.setUint16),
      _1678: Function.prototype.call.bind(DataView.prototype.getInt16),
      _1679: Function.prototype.call.bind(DataView.prototype.setInt16),
      _1680: Function.prototype.call.bind(DataView.prototype.getUint32),
      _1681: Function.prototype.call.bind(DataView.prototype.setUint32),
      _1682: Function.prototype.call.bind(DataView.prototype.getInt32),
      _1683: Function.prototype.call.bind(DataView.prototype.setInt32),
      _1686: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _1687: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _1688: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _1689: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _1690: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _1691: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _1692: Function.prototype.call.bind(Number.prototype.toString),
      _1693: Function.prototype.call.bind(BigInt.prototype.toString),
      _1694: Function.prototype.call.bind(Number.prototype.toString),
      _1695: (d, digits) => d.toFixed(digits),
      _1708: () => globalThis.document,
      _1710: () => globalThis.console,
      _1715: (x0,x1) => { x0.height = x1 },
      _1717: (x0,x1) => { x0.width = x1 },
      _1719: (x0,x1) => { x0.pointerEvents = x1 },
      _1728: x0 => x0.style,
      _1731: x0 => x0.src,
      _1732: (x0,x1) => { x0.src = x1 },
      _1733: x0 => x0.naturalWidth,
      _1734: x0 => x0.naturalHeight,
      _1749: (x0,x1) => x0.error(x1),
      _1754: x0 => x0.status,
      _1755: (x0,x1) => { x0.responseType = x1 },
      _1757: x0 => x0.response,
      _1867: (x0,x1) => { x0.draggable = x1 },
      _1883: x0 => x0.style,
      _2360: (x0,x1) => { x0.src = x1 },
      _2455: x0 => x0.videoWidth,
      _2456: x0 => x0.videoHeight,
      _2460: (x0,x1) => { x0.playsInline = x1 },
      _2485: x0 => x0.error,
      _2486: x0 => x0.src,
      _2487: (x0,x1) => { x0.src = x1 },
      _2495: (x0,x1) => { x0.preload = x1 },
      _2496: x0 => x0.buffered,
      _2499: x0 => x0.currentTime,
      _2500: (x0,x1) => { x0.currentTime = x1 },
      _2501: x0 => x0.duration,
      _2506: (x0,x1) => { x0.playbackRate = x1 },
      _2513: (x0,x1) => { x0.autoplay = x1 },
      _2515: (x0,x1) => { x0.loop = x1 },
      _2517: (x0,x1) => { x0.controls = x1 },
      _2519: (x0,x1) => { x0.volume = x1 },
      _2521: (x0,x1) => { x0.muted = x1 },
      _2536: x0 => x0.code,
      _2537: x0 => x0.message,
      _2610: x0 => x0.length,
      _2806: (x0,x1) => { x0.accept = x1 },
      _2820: x0 => x0.files,
      _2846: (x0,x1) => { x0.multiple = x1 },
      _2864: (x0,x1) => { x0.type = x1 },
      _3583: () => globalThis.window,
      _3645: x0 => x0.navigator,
      _3909: x0 => x0.localStorage,
      _4034: x0 => x0.userAgent,
      _4242: x0 => x0.length,
      _6187: x0 => x0.signal,
      _6248: x0 => x0.firstChild,
      _6259: () => globalThis.document,
      _6319: x0 => x0.documentElement,
      _6382: x0 => x0.fullscreenElement,
      _6673: (x0,x1) => { x0.id = x1 },
      _6700: x0 => x0.children,
      _8019: x0 => x0.value,
      _8021: x0 => x0.done,
      _8201: x0 => x0.size,
      _8209: x0 => x0.name,
      _8215: x0 => x0.length,
      _8220: x0 => x0.result,
      _8717: x0 => x0.url,
      _8719: x0 => x0.status,
      _8721: x0 => x0.statusText,
      _8722: x0 => x0.headers,
      _8723: x0 => x0.body,
      _10851: (x0,x1) => { x0.border = x1 },
      _11129: (x0,x1) => { x0.display = x1 },
      _11293: (x0,x1) => { x0.height = x1 },
      _11983: (x0,x1) => { x0.width = x1 },
      _12351: x0 => x0.name,
      _12352: x0 => x0.message,

    };

    const baseImports = {
      dart2wasm: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      s: [
        "([ \r\n\t]+)|([!-\\[\\]-‧‪-퟿豈-￿][̀-ͯ]*|[\ud800-\udbff][\udc00-\udfff][̀-ͯ]*|\\\\verb\\*([^]).*?\\3|\\\\verb([^*a-zA-Z]).*?\\4|\\\\operatorname\\*|\\\\[a-zA-Z@]+[ \r\n\t]*|\\\\[^\ud800-\udfff])",
      ],
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });
    dartInstance.exports.$setThisModule(dartInstance);

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
