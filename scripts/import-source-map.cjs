// Reproduce the existing application's map document without reimplementing it.
const fs = require('fs');
const vm = require('vm');
const root = '/Users/ersanyakit/Documents/coolvibes/coolvibes/mobile/coolvibes';
const ts = require(root + '/node_modules/typescript');
const source = fs.readFileSync(root + '/components/GameMapView.tsx', 'utf8');
const ast = ts.createSourceFile('map.tsx', source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
const wanted = new Set(['MAPLIBRE_VERSION','STYLE_URL','MAPLIBRE_JS','MAPLIBRE_CSS','MARKER_CSS']);
const chunks = [];
for (const statement of ast.statements) {
  if (ts.isVariableStatement(statement) && statement.declarationList.declarations.some(d => wanted.has(d.name.getText(ast)))) chunks.push(statement.getText(ast));
  if (ts.isFunctionDeclaration(statement) && statement.name?.text === 'buildHtml') chunks.push(statement.getText(ast));
}
const script = ts.transpileModule(chunks.join('\n') + '\nexports.buildHtml = buildHtml;', {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;
const sandbox = {exports:{}};
vm.runInNewContext(script, sandbox);
const init = {preview:false, center:[28.9784,41.0082], zoom:16.5, pitch:65, bearing:-20, markers:[], player:null, interactive:{pan:true,zoom:true,rotate:true,pitch:true}, colors:{ground:['__COOLVIBES_BG_COLOR__']}, appearance:{dark:false,opaque:false}};
let html = sandbox.exports.buildHtml(init);
html = html.replace('var INIT = '+JSON.stringify(init)+';', 'var INIT = __COOLVIBES_INIT_JSON__;');
html = html.replace('<head>', '<head><script>window.ReactNativeWebView={postMessage:function(value){CoolvibesMap.postMessage(value);}};</script>');
fs.writeFileSync('assets/map/game-map.html', html);
const colors = {exports:{}};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(root+'/helpers/appearance/telegramColors.ts','utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText, colors);
const map = {exports:{}, require:()=>colors.exports};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(root+'/helpers/appearance/mapColors.ts','utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText, map);
for (const [name, palette] of Object.entries({day:{accent:'#3390ec',surface:'#ffffff',text:'#000000',wallpaper:{colors:['#dbddbb','#6ba587','#d5d88d','#88b884']}},night:{accent:'#8774e1',surface:'#212121',text:'#ffffff',wallpaper:{colors:['#fec496','#dd6cb9','#962fbf','#4f5bd5']}}})) fs.writeFileSync(`assets/map/palette-${name}.json`, JSON.stringify(map.exports.mapColorsFromPalette(palette),null,2));
