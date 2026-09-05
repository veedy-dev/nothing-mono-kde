// Run: node tests/test-motion.cjs
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
const signal = () => ({ callbacks: [], connect(fn) { this.callbacks.push(fn); }, emit(...args) { this.callbacks.forEach(fn => fn(...args)); } });
const Effect = Object.fromEntries(['WindowAddedGrabRole', 'WindowClosedGrabRole', 'WindowForceBlurRole', 'WindowForceBackgroundContrastRole', 'Scale', 'Opacity'].map((name, i) => [name, i]));
const effects = { windowAdded: signal(), windowClosed: signal(), windowDataChanged: signal(), hasActiveFullScreenEffect: false };
const active = new Map();
let nextId = 1;
let factor = 1;
const config = { OpenDuration: '360', CloseDuration: '180', ScaleInFactor: '0.85' };
const effect = {
    configChanged: signal(), animationEnded: signal(),
    readConfig: (key, fallback) => config[key] ?? fallback,
    isGrabbed: (w, role) => w.data.get(role) != null && w.data.get(role) !== effect,
    grab(w, role) {
        if (this.isGrabbed(w, role)) return false;
        w.setData(role, effect);
        return true;
    }
};
runInNewContext(readFileSync(`${__dirname}/../kwin/effects/bouncingWindows/contents/code/main.js`, 'utf8'), {
    Effect, effects, effect, QEasingCurve: { OutQuint: 14, OutCubic: 6, OutBack: 34, InCubic: 5 },
    animationTime: duration => Math.max(1, duration * factor),
    animate(options) { const ids = [nextId++]; active.set(ids[0], options); return ids; },
    cancel(ids) { ids.forEach(id => active.delete(id)); }
});
function window(overrides = {}) {
    return { managed: true, visible: true, windowClass: 'app app', data: new Map(),
        setData(role, value) { this.data.set(role, value); effects.windowDataChanged.emit(this, role); }, ...overrides };
}
function clean(w) {
    assert.notEqual(w.data.get(Effect.WindowForceBlurRole), true);
    assert.notEqual(w.data.get(Effect.WindowForceBackgroundContrastRole), true);
}
function finish(w) {
    for (const [id, animation] of active) if (animation.window === w) {
        active.delete(id);
        effect.animationEnded.emit(w, 0); // KWin supplies no usable animation id.
    }
}
for (const overrides of [
    { managed: false }, { visible: false },
    ...['popupWindow', 'dock', 'splash', 'toolbar', 'notification', 'onScreenDisplay', 'criticalNotification', 'appletPopup'].map(key => ({ [key]: true })),
    ...['ksmserver ksmserver', 'ksmserver-logout-greeter ksmserver-logout-greeter', 'kscreenlocker_greet kscreenlocker_greet', 'ksplashqml ksplashqml'].map(windowClass => ({ windowClass }))
]) {
    const w = window(overrides);
    effects.windowAdded.emit(w);
    effects.windowClosed.emit(w);
    assert.equal(active.size, 0, `excluded window: ${JSON.stringify(overrides)}`);
    clean(w);
}
const normal = window();
effects.windowAdded.emit(normal);
assert.equal(active.size, 2);
normal.setData(Effect.WindowAddedGrabRole, effect);
assert.equal(active.size, 2, 'own grab notification must not cancel opening');
finish(normal);
clean(normal);

for (const closing of [false, true]) {
    const w = window();
    const role = closing ? Effect.WindowClosedGrabRole : Effect.WindowAddedGrabRole;
    const event = closing ? effects.windowClosed : effects.windowAdded;
    w.setData(role, 'other effect');
    event.emit(w);
    assert.equal(active.size, 0, 'respect an existing grab');
    w.setData(role, null);
    event.emit(w);
    assert.equal(active.size, 2);
    w.setData(role, 'other effect');
    assert.equal(active.size, 0, 'cancel both animations on ownership transfer');
    clean(w);
}
for (const suppressed of ['fullscreen', 'skip', 'grab', 'none']) {
    const w = window();
    effects.windowAdded.emit(w);
    effects.hasActiveFullScreenEffect = suppressed === 'fullscreen';
    w.skipsCloseAnimation = suppressed === 'skip';
    if (suppressed === 'grab') w.setData(Effect.WindowClosedGrabRole, 'other effect');
    effects.windowClosed.emit(w);
    clean(w);
    assert.equal(active.size, suppressed === 'none' ? 2 : 0, 'interrupted opening must not survive close');
    assert.ok([...active.values()].every(a => a.to < a.from), 'exit must shrink/fade');
    finish(w);
    effects.hasActiveFullScreenEffect = false;
}
effects.hasActiveFullScreenEffect = true;
effects.windowAdded.emit(window());
assert.equal(active.size, 0);
effects.hasActiveFullScreenEffect = false;

config.OpenDuration = '420';
config.CloseDuration = '160';
effect.configChanged.emit();
for (factor of [0.25, 0]) {
    const w = window();
    effects.windowAdded.emit(w);
    assert.deepEqual([...active.values()].map(a => a.duration), [Math.max(1, 420 * factor), Math.max(1, 420 * factor)]);
    effects.windowClosed.emit(w);
    assert.deepEqual([...active.values()].map(a => a.duration), [Math.max(1, 160 * factor), Math.max(1, 160 * factor)]);
    clean(w);
    finish(w);
}
console.log('PASS: eligibility, grab ownership, completion/interruption cleanup, and KDE reduced-motion durations');
