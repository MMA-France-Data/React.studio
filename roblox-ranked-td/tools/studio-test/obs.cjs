// Télécommande d'OBS (obs-websocket 5, inclus dans OBS depuis la version 28) pour le mode tournage (tournage.ps1).
//   node obs.cjs start                  -> lance OBS (fermé avant) sur le profil et les scènes « Tower 22 »
//   node obs.cjs calibrate              -> repère la vue 3D de Studio (écran magenta affiché par le scénario) et la
//                                          recadre en 16:9 sur toute l'image (1920 x 1080)
//   node obs.cjs shot <fichier.png>     -> image 1920 x 1080 de la scène
//   node obs.cjs rec-start              -> démarre l'enregistrement
//   node obs.cjs rec-stop <fichier.mp4> -> l'arrête et range la vidéo sous ce nom
//   node obs.cjs finish                 -> arrête l'enregistrement s'il tourne encore (avant de fermer OBS)
//   node obs.cjs restore                -> OBS fermé : remet le profil et les scènes du propriétaire (user.ini)
// OBS garde ses propres réglages : ce script n'utilise que le profil « Tower 22 » (1920 x 1080, 60 images/s, sans
// compte de stream) et la collection « Tower 22 » (fenêtre de Studio + son de Studio seulement, jamais le micro).
// Le mot de passe de la télécommande est lu dans la configuration d'OBS : il n'est écrit nulle part ailleurs.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawn, execSync } = require('child_process');

const OBS_DIR = path.join(process.env.APPDATA, 'obs-studio');
const WS_CONFIG = path.join(OBS_DIR, 'plugin_config', 'obs-websocket', 'config.json');
const OBS_EXE = 'C:\\Program Files\\obs-studio\\bin\\64bit\\obs64.exe';
const OUT = path.join(__dirname, 'out');
const STATE = path.join(OUT, 'obs-state.json');
const PROFILE = 'Tower 22';
const COLLECTION = 'Tower 22';
const SCENE = 'Tournage';
const WINDOW_INPUT = 'Studio (image)';
const AUDIO_INPUT = 'Studio (son)';
const WIDTH = 1920;
const HEIGHT = 1080;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function readState() {
	try {
		return JSON.parse(fs.readFileSync(STATE, 'utf8'));
	} catch {
		return {};
	}
}

function writeState(state) {
	fs.mkdirSync(OUT, { recursive: true });
	fs.writeFileSync(STATE, JSON.stringify(state, null, 1));
}

function obsRunning() {
	try {
		return execSync('tasklist /FI "IMAGENAME eq obs64.exe" /NH', { encoding: 'utf8' }).includes('obs64.exe');
	} catch {
		return false;
	}
}

// Connexion + identification (défi SHA-256 d'obs-websocket 5).
function openSocket(config) {
	return new Promise((resolve, reject) => {
		const ws = new WebSocket(`ws://127.0.0.1:${config.server_port || 4455}`, 'obswebsocket.json');
		const pending = new Map();
		let nextId = 1;
		let identified = false;
		const client = {
			call(requestType, requestData = {}) {
				const requestId = String(nextId++);
				ws.send(JSON.stringify({ op: 6, d: { requestType, requestId, requestData } }));
				return new Promise((res, rej) => pending.set(requestId, { res, rej, requestType }));
			},
			close() {
				ws.close();
			},
		};
		ws.onerror = () => {
			if (!identified) reject(new Error('OBS ne répond pas (télécommande WebSocket)'));
		};
		ws.onclose = () => {
			if (!identified) reject(new Error('connexion refusée par OBS'));
			for (const p of pending.values()) p.rej(new Error('connexion à OBS fermée'));
			pending.clear();
		};
		ws.onmessage = (event) => {
			const msg = JSON.parse(typeof event.data === 'string' ? event.data : Buffer.from(event.data).toString('utf8'));
			if (msg.op === 0) {
				const identify = { rpcVersion: 1, eventSubscriptions: 0 };
				if (msg.d.authentication) {
					const { challenge, salt } = msg.d.authentication;
					const secret = crypto.createHash('sha256').update(String(config.server_password) + salt).digest('base64');
					identify.authentication = crypto.createHash('sha256').update(secret + challenge).digest('base64');
				}
				ws.send(JSON.stringify({ op: 1, d: identify }));
			} else if (msg.op === 2) {
				identified = true;
				resolve(client);
			} else if (msg.op === 7) {
				const p = pending.get(msg.d.requestId);
				if (!p) return;
				pending.delete(msg.d.requestId);
				if (msg.d.requestStatus.result) p.res(msg.d.responseData || {});
				else p.rej(new Error(`${p.requestType} : ${msg.d.requestStatus.code} ${msg.d.requestStatus.comment || ''}`));
			}
		};
	});
}

async function connect(timeoutMs = 20000) {
	const config = JSON.parse(fs.readFileSync(WS_CONFIG, 'utf8'));
	if (!config.server_enabled) throw new Error("La télécommande d'OBS est désactivée (Outils > Paramètres du serveur WebSocket)");
	const deadline = Date.now() + timeoutMs;
	let lastError;
	while (Date.now() < deadline) {
		let obs;
		try {
			obs = await openSocket(config);
			// Juste après son lancement, OBS répond « 207 : pas prêt » pendant quelques secondes.
			await obs.call('GetProfileList');
			return obs;
		} catch (error) {
			lastError = error;
			if (obs) obs.close();
			await sleep(1000);
		}
	}
	throw lastError;
}

// Scène « Tournage » : la fenêtre de Studio (capture Windows 10+, sans le cadre de la fenêtre ni la souris) et le
// son de Studio seulement (ni le son du bureau, ni le micro).
async function ensureScene(obs) {
	const { scenes } = await obs.call('GetSceneList');
	if (!scenes.some((s) => s.sceneName === SCENE)) {
		await obs.call('CreateScene', { sceneName: SCENE });
	}
	await obs.call('SetCurrentProgramScene', { sceneName: SCENE });
	const { inputs } = await obs.call('GetInputList');
	const names = inputs.map((i) => i.inputName);
	if (!names.includes(WINDOW_INPUT)) {
		await obs.call('CreateInput', {
			sceneName: SCENE,
			inputName: WINDOW_INPUT,
			inputKind: 'window_capture',
			inputSettings: { window: 'Roblox Studio:Qt:RobloxStudioBeta.exe', method: 2, priority: 2, cursor: false, client_area: true },
			sceneItemEnabled: true,
		});
	}
	if (!names.includes(AUDIO_INPUT)) {
		await obs.call('CreateInput', {
			sceneName: SCENE,
			inputName: AUDIO_INPUT,
			inputKind: 'wasapi_process_output_capture',
			inputSettings: { window: 'Roblox Studio:Qt:RobloxStudioBeta.exe', priority: 2 },
			sceneItemEnabled: true,
		});
	}
	const special = await obs.call('GetSpecialInputs');
	for (const key of ['desktop1', 'desktop2', 'mic1', 'mic2', 'mic3', 'mic4']) {
		if (special[key]) {
			await obs.call('RemoveInput', { inputName: special[key] }).catch(() => {});
		}
	}
}

// Profil et collection de scènes utilisés en dernier par le propriétaire (section [Basic] de user.ini) : OBS les
// réécrit en se fermant, restore les remet ensuite.
const USER_INI = path.join(OBS_DIR, 'user.ini');
const BASIC_KEYS = ['Profile', 'ProfileDir', 'SceneCollection', 'SceneCollectionFile'];

function readBasic() {
	const text = fs.readFileSync(USER_INI, 'utf8').replace(/^﻿/, '');
	const values = {};
	for (const key of BASIC_KEYS) {
		const match = text.match(new RegExp(`^${key}=(.*)$`, 'm'));
		if (match) values[key] = match[1].replace(/\r$/, '');
	}
	return values;
}

// OBS est lancé DIRECTEMENT sur le profil et la collection « Tower 22 » (options --profile et --collection) : on ne
// change jamais de profil pendant qu'il tourne (passer du profil du propriétaire, avec son chat Twitch, à celui-ci a
// fait planter OBS le 30/09/2026 : obs-browser, QCefBrowserClient::OnBeforeClose).
async function start() {
	if (obsRunning()) {
		throw new Error("OBS est déjà ouvert : ferme-le avant le tournage (il sera relancé sur le profil « Tower 22 »)");
	}
	if (!fs.existsSync(path.join(OBS_DIR, 'basic', 'profiles', 'Tower_22', 'basic.ini'))) {
		throw new Error(`Profil OBS « ${PROFILE} » introuvable (dossier basic/profiles/Tower_22)`);
	}
	writeState({ basic: readBasic() });
	spawn(
		OBS_EXE,
		['--profile', PROFILE, '--collection', COLLECTION, '--minimize-to-tray', '--disable-shutdown-check', '--disable-updater', '--disable-missing-files-check'],
		{ cwd: path.dirname(OBS_EXE), detached: true, stdio: 'ignore' }
	).unref();
	const obs = await connect(60000);
	const profiles = await obs.call('GetProfileList');
	const collections = await obs.call('GetSceneCollectionList');
	if (profiles.currentProfileName !== PROFILE || collections.currentSceneCollectionName !== COLLECTION) {
		obs.close();
		throw new Error(`OBS n'a pas démarré sur « ${PROFILE} » (profil « ${profiles.currentProfileName} », scènes « ${collections.currentSceneCollectionName} »)`);
	}
	await ensureScene(obs);
	const video = await obs.call('GetVideoSettings');
	console.log(`OBS prêt : profil « ${PROFILE} », scène « ${SCENE} », ${video.outputWidth} x ${video.outputHeight}, ${video.fpsNumerator / video.fpsDenominator} images/s`);
	obs.close();
}

// Choisit la fenêtre principale de Studio parmi les fenêtres proposées par OBS (sinon : la première de Studio).
async function pickStudioWindow(obs) {
	for (const input of [WINDOW_INPUT, AUDIO_INPUT]) {
		const { propertyItems } = await obs.call('GetInputPropertiesListPropertyItems', { inputName: input, propertyName: 'window' });
		const studio = propertyItems.filter((item) => /RobloxStudioBeta\.exe/i.test(item.itemValue || ''));
		const main = studio.find((item) => /Roblox Studio/i.test(item.itemName || '')) || studio[0];
		if (main) {
			await obs.call('SetInputSettings', { inputName: input, inputSettings: { window: main.itemValue } });
		}
	}
}

// Image BMP (24 ou 32 bits) -> { width, height, rgb(x, y) }.
function parseBmp(buffer) {
	const offset = buffer.readUInt32LE(10);
	const width = buffer.readInt32LE(18);
	const rawHeight = buffer.readInt32LE(22);
	const bpp = buffer.readUInt16LE(28);
	const height = Math.abs(rawHeight);
	const bottomUp = rawHeight > 0;
	const stride = Math.floor((bpp * width + 31) / 32) * 4;
	const bytes = bpp / 8;
	return {
		width,
		height,
		rgb(x, y) {
			const row = bottomUp ? height - 1 - y : y;
			const i = offset + row * stride + x * bytes;
			return [buffer[i + 2], buffer[i + 1], buffer[i]];
		},
	};
}

async function calibrate() {
	const obs = await connect();
	await pickStudioWindow(obs);
	await sleep(800);
	let box;
	let size;
	for (let attempt = 1; attempt <= 6 && !box; attempt++) {
		const shot = await obs.call('GetSourceScreenshot', { sourceName: WINDOW_INPUT, imageFormat: 'bmp' });
		const image = parseBmp(Buffer.from(shot.imageData.split(',')[1], 'base64'));
		size = image;
		let x0 = Infinity;
		let y0 = Infinity;
		let x1 = -1;
		let y1 = -1;
		let count = 0;
		for (let y = 0; y < image.height; y += 1) {
			for (let x = 0; x < image.width; x += 1) {
				const [r, g, b] = image.rgb(x, y);
				if (r > 235 && g < 25 && b > 235) {
					count++;
					if (x < x0) x0 = x;
					if (x > x1) x1 = x;
					if (y < y0) y0 = y;
					if (y > y1) y1 = y;
				}
			}
		}
		if (count > 10000) box = { x0, y0, x1, y1 };
		else await sleep(700);
	}
	if (!box) throw new Error("Écran magenta introuvable dans l'image de Studio");
	const vw = box.x1 - box.x0 + 1;
	const vh = box.y1 - box.y0 + 1;
	let cw = vw;
	let ch = vh;
	if (vw / vh > WIDTH / HEIGHT) cw = Math.round((vh * WIDTH) / HEIGHT);
	else ch = Math.round((vw * HEIGHT) / WIDTH);
	const cx = box.x0 + Math.floor((vw - cw) / 2);
	const cy = box.y0 + Math.floor((vh - ch) / 2);
	const { sceneItemId } = await obs.call('GetSceneItemId', { sceneName: SCENE, sourceName: WINDOW_INPUT });
	await obs.call('SetSceneItemTransform', {
		sceneName: SCENE,
		sceneItemId,
		sceneItemTransform: {
			cropLeft: cx,
			cropTop: cy,
			cropRight: size.width - (cx + cw),
			cropBottom: size.height - (cy + ch),
			positionX: 0,
			positionY: 0,
			alignment: 5,
			boundsType: 'OBS_BOUNDS_STRETCH',
			boundsWidth: WIDTH,
			boundsHeight: HEIGHT,
			boundsAlignment: 0,
		},
	});
	const state = readState();
	state.viewport = { window: [size.width, size.height], box, crop: [cx, cy, cw, ch] };
	writeState(state);
	console.log(`Vue 3D de Studio : ${vw} x ${vh} (fenêtre ${size.width} x ${size.height}) ; image gardée ${cw} x ${ch} à (${cx}, ${cy}) -> ${WIDTH} x ${HEIGHT}`);
	obs.close();
}

async function shot(file) {
	const obs = await connect();
	await obs.call('SaveSourceScreenshot', {
		sourceName: SCENE,
		imageFormat: 'png',
		imageFilePath: path.resolve(file),
		imageWidth: WIDTH,
		imageHeight: HEIGHT,
	});
	console.log(`Image : ${path.resolve(file)}`);
	obs.close();
}

async function recStart() {
	const obs = await connect();
	const status = await obs.call('GetRecordStatus');
	if (!status.outputActive) await obs.call('StartRecord');
	console.log('Enregistrement démarré');
	obs.close();
}

async function recStop(file) {
	const obs = await connect();
	const status = await obs.call('GetRecordStatus');
	if (!status.outputActive) {
		console.log("Pas d'enregistrement en cours");
		obs.close();
		return;
	}
	const { outputPath } = await obs.call('StopRecord');
	obs.close();
	const target = path.resolve(file);
	fs.mkdirSync(path.dirname(target), { recursive: true });
	for (let attempt = 1; attempt <= 40; attempt++) {
		try {
			fs.renameSync(outputPath, target);
			console.log(`Vidéo : ${target}`);
			return;
		} catch {
			await sleep(500);
		}
	}
	console.log(`Vidéo laissée à ${outputPath}`);
}

// Avant de fermer OBS : arrête l'enregistrement s'il tourne encore.
async function finish() {
	if (!obsRunning()) return;
	const obs = await connect(10000);
	const status = await obs.call('GetRecordStatus');
	if (status.outputActive) {
		await obs.call('StopRecord');
		await sleep(1500);
	}
	obs.close();
}

// Après la fermeture d'OBS : remet le profil et la collection de scènes du propriétaire (user.ini) et efface les
// marqueurs de lancement laissés si OBS a dû être arrêté de force (sinon il proposerait le « mode sans échec »).
async function restore() {
	if (obsRunning()) throw new Error("OBS tourne encore : ferme-le d'abord");
	const saved = readState().basic;
	if (saved) {
		const raw = fs.readFileSync(USER_INI, 'utf8');
		const bom = raw.startsWith('﻿') ? '﻿' : '';
		let text = raw.replace(/^﻿/, '');
		for (const key of BASIC_KEYS) {
			if (saved[key] !== undefined) {
				text = text.replace(new RegExp(`^${key}=.*$`, 'm'), `${key}=${saved[key]}`);
			}
		}
		fs.writeFileSync(USER_INI, bom + text, 'utf8');
	}
	const sentinel = path.join(OBS_DIR, '.sentinel');
	if (fs.existsSync(sentinel)) {
		for (const name of fs.readdirSync(sentinel)) fs.rmSync(path.join(sentinel, name), { force: true });
	}
	const basic = readBasic();
	console.log(`OBS remis comme avant : profil « ${basic.Profile} », scènes « ${basic.SceneCollection} »`);
}

const [command, arg] = process.argv.slice(2);
const commands = {
	start,
	calibrate,
	shot: () => shot(arg),
	'rec-start': recStart,
	'rec-stop': () => recStop(arg),
	finish,
	restore,
};
if (!commands[command]) {
	console.log('Commandes : start | calibrate | shot <fichier.png> | rec-start | rec-stop <fichier.mp4> | finish | restore');
	process.exit(1);
}
commands[command]().then(
	() => process.exit(0),
	(error) => {
		console.error(`Erreur OBS : ${error.message}`);
		process.exit(1);
	}
);
