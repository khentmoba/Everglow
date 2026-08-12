import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

// Offscreen three.js renderer for the roaming Guardian. It draws the same
// chibi_cat.glb into a hidden WebGL canvas and exposes a per-frame RGBA
// snapshot to Dart, which composites it into the Flutter canvas. Because the
// cat is real canvas content, it can be occluded by dashboard widgets (unlike
// a DOM platform view, which always composites on top).

const W = 256;
const H = 256;
const GLB_PATH = "assets/assets/models/chibi_cat.glb";

let renderer = null;
let scene = null;
let camera = null;
let model = null;
let baseScale = 1;
let ready = false;

const params = {
  facing: 1,
  activity: "idle",
  turning: false,
  moving: false,
  bob: 0,
  breath: 1,
  scale: 1,
  held: false,
};

const pixels = new Uint8Array(W * H * 4);
const tmpRow = new Uint8Array(W * 4);

function init() {
  const canvas = document.createElement("canvas");
  canvas.width = W;
  canvas.height = H;
  canvas.style.display = "none";
  document.body.appendChild(canvas);

  renderer = new THREE.WebGLRenderer({
    canvas: canvas,
    alpha: true,
    antialias: true,
    preserveDrawingBuffer: true,
  });
  renderer.setClearColor(0x000000, 0);
  renderer.setSize(W, H, false);

  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(35, 1, 0.1, 100);
  camera.position.set(0, 1.5, 3.6);
  camera.lookAt(0, 0.1, 0);

  scene.add(new THREE.HemisphereLight(0xffffff, 0x554455, 1.1));

  const key = new THREE.DirectionalLight(0xffffff, 1.5);
  key.position.set(2.5, 4, 3);
  scene.add(key);

  const fill = new THREE.DirectionalLight(0xddc8ff, 0.55);
  fill.position.set(-3, 1, -2);
  scene.add(fill);

  new GLTFLoader().load(GLB_PATH, (gltf) => {
    model = gltf.scene;
    const box = new THREE.Box3().setFromObject(model);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z) || 1;
    baseScale = 2.0 / maxDim;
    model.scale.setScalar(baseScale);
    model.position.set(
      -center.x * baseScale,
      -center.y * baseScale,
      -center.z * baseScale,
    );
    scene.add(model);
    ready = true;
  });
}

function setParams(p) {
  params.facing = p.facing ?? 1;
  params.activity = p.activity ?? "idle";
  params.turning = !!p.turning;
  params.moving = !!p.moving;
  params.bob = p.bob ?? 0;
  params.breath = p.breath ?? 1;
  params.scale = p.scale ?? 1;
  params.held = !!p.held;
}

function renderToBytes() {
  if (!ready || !model || !renderer) return null;

  const now = performance.now() / 1000;
  const baseYaw = params.facing < 0 ? Math.PI : 0;
  let yaw = baseYaw;
  if (params.turning) {
    yaw = now * 6;
  } else if (params.activity === "idle") {
    yaw = baseYaw + now * 0.6;
  }
  model.rotation.y = yaw;

  model.position.y = params.bob * 0.02;
  model.scale.setScalar(baseScale * params.breath * params.scale);

  renderer.render(scene, camera);
  const gl = renderer.getContext();
  gl.readPixels(0, 0, W, H, gl.RGBA, gl.UNSIGNED_BYTE, pixels);

  // WebGL rows are bottom-up; flip so row 0 is the top of the image.
  for (let y = 0; y < H / 2; y++) {
    const a = y * W * 4;
    const b = (H - 1 - y) * W * 4;
    tmpRow.set(pixels.subarray(a, a + W * 4));
    pixels.set(pixels.subarray(b, b + W * 4), a);
    pixels.set(tmpRow, b);
  }
  return pixels;
}

window.EverglowCat3D = {
  setParams,
  renderToBytes,
  get ready() {
    return ready;
  },
};

init();
