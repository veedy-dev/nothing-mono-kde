#include <KFilePlacesView>
#include <KUrlComboBox>
#include <KUrlNavigator>
#include <QApplication>
#include <QFileInfo>
#include <QImage>
#include <QLineEdit>
#include <QPainter>
#include <QPluginLoader>
#include <QStylePlugin>
#include <QStyleFactory>
#include <QStyleOption>
#include <QTabBar>
#include <QToolBar>
#include <cstdio>
#include <cstdlib>
#include <memory>

// Dolphin's tab class is not exported; use its native Qt base and metaobject name.
class DolphinTabBar : public QTabBar
{
    Q_OBJECT
};

static void require(bool condition, const char *message)
{
    if (!condition) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        std::exit(1);
    }
}

template<typename Draw>
static QImage paint(Draw draw)
{
    QImage image(160, 36, QImage::Format_ARGB32_Premultiplied);
    image.fill(QColor("#121212"));
    QPainter painter(&image);
    draw(&painter);
    return image;
}

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    require(argc == 2, "pass the built plugin path");
    QPluginLoader plugin(QFileInfo(argv[1]).absoluteFilePath());
    auto *factory = qobject_cast<QStylePlugin *>(plugin.instance());
    require(factory, "load built plugin directly without an installed-key collision");
    app.setApplicationName("dolphin");
    app.setDesktopFileName("org.kde.dolphin");
    auto *style = factory->create("NothingDolphin");
    require(style, "create Dolphin style from built plugin");
    app.setStyle(style);
    std::unique_ptr<QStyle> breeze(QStyleFactory::create("Breeze"));
    require(bool(breeze), "real Breeze available");
    QPalette palette = breeze->standardPalette();
    palette.setColor(QPalette::Window, QColor("#121212"));
    palette.setColor(QPalette::Base, QColor("#121212"));
    palette.setColor(QPalette::AlternateBase, QColor("#121212"));
    palette.setColor(QPalette::Highlight, QColor("#3b3b3b"));
    app.setPalette(palette);

    DolphinTabBar tabs;
    tabs.setMovable(true);
    tabs.setTabsClosable(true);
    QStyleOptionTab tab;
    tab.rect = QRect(0, 0, 160, 36);
    tab.palette = palette;
    tab.text = "Folder";
    tab.shape = QTabBar::RoundedNorth;
    tab.position = QStyleOptionTab::OnlyOneTab;
    tab.documentMode = true;
    tab.state = QStyle::State_Enabled | QStyle::State_Active;
    auto tabImage = [&](QStyle *s, QWidget *w) {
        return paint([&](QPainter *p) { s->drawControl(QStyle::CE_TabBarTab, &tab, p, w); });
    };
    const QImage normal = tabImage(style, &tabs);
    require(normal.pixelColor(20, 18) == QColor("#191919"), "normal Dolphin tab fill is #191919");
    require(tabImage(breeze.get(), &tabs).pixelColor(20, 18) != QColor("#191919"), "baseline tab differs");
    for (auto state : {QStyle::State_Selected, QStyle::State_MouseOver, QStyle::State_HasFocus, QStyle::State_Sunken}) {
        tab.state = QStyle::State_Enabled | QStyle::State_Active | state;
        require(tabImage(style, &tabs) == tabImage(breeze.get(), &tabs), "selected/hover/focus/pressed tab native pixels preserved");
    }
    tab.state = QStyle::State_None;
    require(tabImage(style, &tabs) == tabImage(breeze.get(), &tabs), "disabled tab native pixels preserved");
    tab.state = QStyle::State_Enabled | QStyle::State_Active;
    QTabBar ordinaryTabs;
    require(tabImage(style, &ordinaryTabs) == tabImage(breeze.get(), &ordinaryTabs), "non-Dolphin tab pixels unchanged");

    QToolBar toolbar;
    auto *navigator = new KUrlNavigator(&toolbar);
    toolbar.addWidget(navigator);
    toolbar.resize(600, 60);
    navigator->setLocationUrl(QUrl::fromLocalFile("/tmp"));
    toolbar.show();
    app.processEvents();
    navigator->ensurePolished();
    QStyleOptionFrame frame;
    frame.rect = tab.rect;
    frame.palette = palette;
    frame.state = QStyle::State_Enabled | QStyle::State_Active;
    frame.lineWidth = 1;
    auto frameImage = [&](QStyle *s, QWidget *w) {
        return paint([&](QPainter *p) { s->drawPrimitive(QStyle::PE_FrameLineEdit, &frame, p, w); });
    };
    require(frameImage(style, navigator).pixelColor(80, 18) == QColor("#191919"), "breadcrumb native frame fill");
    QLineEdit ordinaryEdit;
    require(frameImage(style, &ordinaryEdit) == frameImage(breeze.get(), &ordinaryEdit), "ordinary edit unchanged");
    frame.state = QStyle::State_None;
    require(frameImage(style, navigator) == frameImage(breeze.get(), navigator), "disabled frame unchanged");
    frame.state = QStyle::State_Enabled | QStyle::State_Active;

    QStyleOptionComboBox combo;
    combo.rect = tab.rect;
    combo.palette = palette;
    combo.state = frame.state;
    combo.editable = true;
    combo.subControls = QStyle::SC_All;
    auto comboImage = [&](QStyle *s, QWidget *w) {
        return paint([&](QPainter *p) { s->drawComplexControl(QStyle::CC_ComboBox, &combo, p, w); });
    };
    require(comboImage(style, navigator->editor()).pixelColor(80, 18) == QColor("#191919"), "editable path combo fill");
    QComboBox ordinaryCombo;
    require(comboImage(style, &ordinaryCombo) == comboImage(breeze.get(), &ordinaryCombo), "ordinary combo unchanged");
    auto editImage = [&](QStyle *s) {
        return paint([&](QPainter *p) { s->drawPrimitive(QStyle::PE_PanelLineEdit, &frame, p, navigator->editor()->lineEdit()); });
    };
    require(editImage(style).pixelColor(80, 18) == QColor("#191919"), "editable path text-field fill");

    // Actual KIO paint lifecycle: Dolphin can disable native fill after polish.
    navigator->setUrlEditable(false);
    navigator->setBackgroundEnabled(false);
    const QImage breadcrumb = navigator->grab().toImage();
    require(breadcrumb.pixelColor(400, breadcrumb.height() / 2) == QColor("#191919"), "native KIO painting restores breadcrumb fill after reset");
    navigator->setEnabled(false);
    const QImage disabled = navigator->grab().toImage();
    require(disabled.pixelColor(400, disabled.height() / 2) == palette.color(QPalette::Disabled, QPalette::AlternateBase), "actual disabled KIO background unchanged");
    navigator->setEnabled(true);
    navigator->setUrlEditable(true);
    const QImage editable = navigator->grab().toImage();
    require(editable.pixelColor(400, editable.height() / 2) == QColor("#191919"), "actual editable KIO path fill");
    QWidget dialog;
    navigator->setParent(&dialog);
    require(frameImage(style, navigator) == frameImage(breeze.get(), navigator), "reparented dialog navigator unchanged");

    KFilePlacesView places;
    places.ensurePolished();
    style->polish(&places); // Re-polish must not replace the original palette with the accent.
    QStyleOptionViewItem item;
    item.rect = tab.rect;
    item.widget = &places;
    item.showDecorationSelected = true;
    auto panelImage = [&](QStyle *s, const QPalette &colors, const QWidget *w = nullptr) {
        item.palette = colors;
        return paint([&](QPainter *p) { s->drawPrimitive(QStyle::PE_PanelItemViewItem, &item, p, w); });
    };
    for (auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
        auto nativePalette = palette;
        auto placesPalette = places.palette();
        nativePalette.setCurrentColorGroup(group);
        placesPalette.setCurrentColorGroup(group);
        for (auto state : {QStyle::State_Selected, QStyle::State_MouseOver}) {
            item.state = QStyle::State_Enabled | QStyle::State_Active | state;
            require(panelImage(style, placesPalette) == panelImage(breeze.get(), nativePalette),
                "Places selected/hover pixels stay native across palette groups without widget argument");
        }
    }
    item.state = QStyle::State_Enabled | QStyle::State_Active | QStyle::State_Selected;
    item.widget = nullptr;
    require(panelImage(style, places.palette(), &places) == panelImage(breeze.get(), palette, &places),
        "Places explicit-widget selection stays native");
    QListView ordinaryList;
    ordinaryList.ensurePolished();
    item.widget = &ordinaryList;
    require(panelImage(style, ordinaryList.palette()) == panelImage(breeze.get(), palette),
        "ordinary list selection stays native");
    item.widget = &places;
    // Unresolved original roles must follow a subsequent application scheme change.
    auto changedPalette = palette;
    changedPalette.setColor(QPalette::Highlight, QColor("#454545"));
    app.setPalette(changedPalette);
    require(panelImage(style, places.palette()) == panelImage(breeze.get(), changedPalette),
        "Places selection follows application palette changes");
    style->unpolish(&places);
    require(panelImage(breeze.get(), places.palette()) == panelImage(breeze.get(), changedPalette),
        "unpolish restores native Places selection after repeated polish");
    app.setPalette(palette);

    app.setApplicationName("other-app");
    app.setDesktopFileName("org.example.other");
    std::unique_ptr<QStyle> other(factory->create("NothingDolphin"));
    require(bool(other), "other app style available");
    require(tabImage(other.get(), &tabs) == tabImage(breeze.get(), &tabs), "other app target-named tab unchanged");
    require(frameImage(other.get(), navigator) == frameImage(breeze.get(), navigator), "other app path unchanged");
    std::printf("PASS: Qt %s; style=%s; tab/breadcrumb/editable=#191919; native selected/hover/focus/pressed/disabled and unrelated controls pixel-identical; real KIO reset/edit-mode/reparent lifecycle verified; Places native selection/hover, palette changes and unpolish verified; other-app passthrough verified\n", qVersion(), qPrintable(style->name()));
}

#include "test-dolphin-style.moc"
