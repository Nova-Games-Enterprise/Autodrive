import { spawnSync } from 'node:child_process';
import fs from 'node:fs';

function run(command, args) {
  const result = spawnSync(command, args, { stdio:'inherit', shell:false });
  if (result.error) throw new Error(`Cannot run ${command}: ${result.error.message}. Set LUA_BIN to a Lua 5.4 interpreter.`);
  if (result.status !== 0) process.exit(result.status || 1);
}
const lua = process.env.LUA_BIN || (process.platform === 'win32' ? 'lua' : 'lua5.4');
run(lua, ['-v']);
run(lua, ['tests/run.lua']);
run(process.execPath, ['--check','html/index.js']);
run(process.execPath, ['--test','tests/ui.test.mjs']);
for (const path of ['server/main.lua','client/main.lua','client/sensors.lua','client/controller.lua','client/hud.lua']) {
  const text=fs.readFileSync(path,'utf8');
  if (/\b(?:RegisterNetEvent|TriggerServerEvent|TriggerClientEvent|PerformHttpRequest|SetVehicleHandbrake|SetVehicleBrake)\s*\(/.test(text)) {
    throw new Error(`Unexpected network or latched-brake API in factory-only preview: ${path}`);
  }
}
console.log('Verification complete. Native/in-game and visual acceptance are separate, pending gates.');
