"use strict";

var blacklist = [
    "ksmserver ksmserver",
    "ksmserver-logout-greeter ksmserver-logout-greeter",
    "kscreenlocker_greet kscreenlocker_greet",
    "ksplashqml ksplashqml"
];

function isNormalWindow(window) {
    if (blacklist.indexOf(window.windowClass) !== -1) {
        return false;
    }

    if (!window.managed) {
        return false;
    }

    if (window.popupWindow ||
        window.dock ||
        window.splash ||
        window.toolbar ||
        window.notification ||
        window.onScreenDisplay ||
        window.criticalNotification ||
        window.appletPopup) {
        return false;
    }

    return true;
}

function setWindowVisualRoles(window, enabled) {
    window.setData(Effect.WindowForceBlurRole, enabled);
    window.setData(Effect.WindowForceBackgroundContrastRole, enabled);
}
function cancelOpening(window) {
    if (window.scaleInAnimation) cancel(window.scaleInAnimation);
    if (window.opacityInAnimation) cancel(window.opacityInAnimation);
    delete window.scaleInAnimation;
    delete window.opacityInAnimation;
    setWindowVisualRoles(window, null);
}
var bounceWindowsEffect = {
    openDuration: 500,
    closeDuration: 240,
    scaleInFactor: 0.9,
    scaleOutFactor: 0.96,

    loadConfig: function () {
        // Wrapped in parse functions so KWin doesn't accidentally pass strings to the animation engine
        this.openDuration = parseInt(effect.readConfig("OpenDuration", 500), 10);
        this.closeDuration = parseInt(effect.readConfig("CloseDuration", 240), 10);
        this.scaleInFactor = parseFloat(effect.readConfig("ScaleInFactor", 0.9));
    },

    slotWindowAdded: function (window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }

        if (!isNormalWindow(window) || !window.visible) {
            return;
        }

        if (!effect.grab(window, Effect.WindowAddedGrabRole)) {
            return;
        }

        setWindowVisualRoles(window, true);

        window.scaleInAnimation = animate({
            window: window,
            curve: QEasingCurve.OutQuint,
            duration: animationTime(bounceWindowsEffect.openDuration),
            type: Effect.Scale,
            from: bounceWindowsEffect.scaleInFactor,
            to: 1.0
        });

        window.opacityInAnimation = animate({
            window: window,
            curve: QEasingCurve.OutCubic,
            duration: animationTime(bounceWindowsEffect.openDuration),
            type: Effect.Opacity,
            from: 0.0,
            to: 1.0
        });
    },

    slotWindowClosed: function (window) {
        // Opening must release its visual roles even if another effect owns the exit.
        if (window.scaleInAnimation || window.opacityInAnimation) cancelOpening(window);
        if (effects.hasActiveFullScreenEffect) {
            return;
        }

        if (!isNormalWindow(window) || !window.visible || window.skipsCloseAnimation) {
            return;
        }

        if (!effect.grab(window, Effect.WindowClosedGrabRole)) {
            return;
        }

        window.scaleOutAnimation = animate({
            window: window,
            curve: QEasingCurve.OutCubic,
            duration: animationTime(bounceWindowsEffect.closeDuration),
            type: Effect.Scale,
            from: 1.0,
            to: bounceWindowsEffect.scaleOutFactor
        });

        window.opacityOutAnimation = animate({
            window: window,
            curve: QEasingCurve.OutCubic,
            duration: animationTime(bounceWindowsEffect.closeDuration),
            type: Effect.Opacity,
            from: 1.0,
            to: 0.0
        });
    },

    slotWindowDataChanged: function (window, role) {
        if (!effect.isGrabbed(window, role)) return;
        if (role === Effect.WindowAddedGrabRole) {
            if (window.scaleInAnimation || window.opacityInAnimation) cancelOpening(window);
        } else if (role === Effect.WindowClosedGrabRole) {
            if (window.scaleOutAnimation) cancel(window.scaleOutAnimation);
            if (window.opacityOutAnimation) cancel(window.opacityOutAnimation);
            delete window.scaleOutAnimation;
            delete window.opacityOutAnimation;
        }
    },

    init: function () {
        this.loadConfig();
        effect.animationEnded.connect(function(window) {
            setWindowVisualRoles(window, null);
        });
        // CRITICAL FIX: This must be 'effect' (singular), not 'effects'
        effect.configChanged.connect(function() {
            bounceWindowsEffect.loadConfig();
        });

        effects.windowAdded.connect(this.slotWindowAdded);
        effects.windowClosed.connect(this.slotWindowClosed);
        effects.windowDataChanged.connect(this.slotWindowDataChanged);
    }
};

bounceWindowsEffect.init();
