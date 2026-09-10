#include <KUrlNavigator>
#include <QApplication>
#include <QEvent>
#include <QProxyStyle>
#include <QStyleFactory>
#include <QStyleOption>
#include <QStylePlugin>
#include <QWidget>
#include <QVariant>

namespace {
constexpr auto placesPaletteProperty = "_nothingDolphin_originalPlacesPalette";

bool isNavigator(const QWidget *widget)
{
    if (!widget || !widget->inherits("KUrlNavigator")) {
        return false;
    }
    for (const QWidget *parent = widget->parentWidget(); parent; parent = parent->parentWidget()) {
        if (parent->inherits("QToolBar")) {
            return true;
        }
    }
    return false;
}

bool isPathEditor(const QWidget *widget)
{
    if (!widget) {
        return false;
    }
    if (widget->inherits("QLineEdit")) {
        widget = widget->parentWidget();
    }
    return widget && widget->inherits("KUrlComboBox") && isNavigator(widget->parentWidget());
}

class DolphinStyle final : public QProxyStyle
{
public:
    explicit DolphinStyle(QStyle *breeze) : QProxyStyle(breeze) {}

    using QProxyStyle::polish;
    using QProxyStyle::unpolish;

    void polish(QWidget *widget) override
    {
        QProxyStyle::polish(widget);
        if (widget->inherits("KUrlNavigator")) {
            widget->installEventFilter(this);
        }
        if (widget->inherits("KFilePlacesView") && !widget->property(placesPaletteProperty).isValid()) {
            auto palette = widget->palette();
            widget->setProperty(placesPaletteProperty, palette);
            // KIO paints capacity fills directly with Highlight, not CE_ProgressBar.
            palette.setColor(QPalette::Highlight, QColor(0xf2, 0x5e, 0x70));
            widget->setPalette(palette);
        }
    }

    void unpolish(QWidget *widget) override
    {
        widget->removeEventFilter(this);
        QProxyStyle::unpolish(widget);
        const auto original = widget->property(placesPaletteProperty);
        if (original.isValid()) {
            widget->setPalette(original.value<QPalette>());
            widget->setProperty(placesPaletteProperty, QVariant());
        }
    }

    bool eventFilter(QObject *object, QEvent *event) override
    {
        if (event->type() == QEvent::Paint) {
            if (auto *navigator = qobject_cast<KUrlNavigator *>(object)) {
                // Dolphin disables this for custom style names, also after polish.
                // Retain KIO's native focus, context-menu and editable-mode painting.
                if (isNavigator(navigator) && !navigator->isBackgroundEnabled()) {
                    navigator->setBackgroundEnabled(true);
                }
            }
        }
        return QProxyStyle::eventFilter(object, event);
    }

    void drawPrimitive(PrimitiveElement element, const QStyleOption *option, QPainter *painter,
                       const QWidget *widget = nullptr) const override
    {
        if (element == PE_PanelItemViewItem) {
            if (const auto *item = qstyleoption_cast<const QStyleOptionViewItem *>(option)) {
                // The KIO delegate omits the widget argument; Qt stores the view in the option.
                const QWidget *view = item->widget ? item->widget : widget;
                if (view && view->inherits("KFilePlacesView")) {
                    const auto original = view->property(placesPaletteProperty);
                    if (original.isValid()) {
                        auto adjusted = *item;
                        const auto palette = original.value<QPalette>().resolve(QApplication::palette(view));
                        for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
                            adjusted.palette.setBrush(group, QPalette::Highlight, palette.brush(group, QPalette::Highlight));
                        }
                        // Keep native row selection/hover without changing the delegate's fill palette.
                        QProxyStyle::drawPrimitive(element, &adjusted, painter, widget);
                        return;
                    }
                }
            }
        }
        if (widget && widget->isEnabled() && (option->state & State_Enabled)
            && ((element == PE_FrameLineEdit && isNavigator(widget))
                || ((element == PE_FrameLineEdit || element == PE_PanelLineEdit) && isPathEditor(widget)))) {
            if (const auto *frame = qstyleoption_cast<const QStyleOptionFrame *>(option)) {
                auto adjusted = *frame;
                adjusted.palette.setColor(QPalette::Base, QColor(0x19, 0x19, 0x19));
                QProxyStyle::drawPrimitive(element, &adjusted, painter, widget);
                return;
            }
        }
        QProxyStyle::drawPrimitive(element, option, painter, widget);
    }

    void drawControl(ControlElement element, const QStyleOption *option, QPainter *painter,
                     const QWidget *widget = nullptr) const override
    {
        if (element == CE_TabBarTabShape && widget && widget->inherits("DolphinTabBar")
            && (option->state & State_Enabled)
            && !(option->state & (State_Selected | State_MouseOver | State_Sunken | State_HasFocus))) {
            if (const auto *tab = qstyleoption_cast<const QStyleOptionTab *>(option)) {
                auto adjusted = *tab;
                // Breeze darkens only the unselected tab fill by 120%; #1e1e1e becomes #191919.
                adjusted.palette.setColor(QPalette::Window, QColor(0x1e, 0x1e, 0x1e));
                QProxyStyle::drawControl(element, &adjusted, painter, widget);
                return;
            }
        }
        QProxyStyle::drawControl(element, option, painter, widget);
    }

    void drawComplexControl(ComplexControl control, const QStyleOptionComplex *option, QPainter *painter,
                            const QWidget *widget = nullptr) const override
    {
        if (control == CC_ComboBox && (option->state & State_Enabled) && isPathEditor(widget)) {
            if (const auto *combo = qstyleoption_cast<const QStyleOptionComboBox *>(option); combo && combo->editable) {
                auto adjusted = *combo;
                adjusted.palette.setColor(QPalette::Base, QColor(0x19, 0x19, 0x19));
                // Breeze calls its own frame helper here, bypassing the proxy's primitive override.
                QProxyStyle::drawComplexControl(control, &adjusted, painter, widget);
                return;
            }
        }
        QProxyStyle::drawComplexControl(control, option, painter, widget);
    }
};

}

class DolphinStylePlugin final : public QStylePlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QStyleFactoryInterface" FILE "style.json")
public:
    QStyle *create(const QString &key) override
    {
        if (key.compare(QStringLiteral("NothingDolphin"), Qt::CaseInsensitive) != 0) {
            return nullptr;
        }
        QStyle *breeze = QStyleFactory::create(QStringLiteral("Breeze"));
        if (!breeze) {
            return nullptr;
        }
        if (QApplication::applicationName().compare(QStringLiteral("dolphin"), Qt::CaseInsensitive) != 0
            && QApplication::desktopFileName() != QStringLiteral("org.kde.dolphin")) {
            return breeze;
        }
        return new DolphinStyle(breeze);
    }
};

#include "style.moc"
