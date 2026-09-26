#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTranslator>

#include "qmlavplayer.h"
#include "context.h"
#include "eventfilter.h"
#include "clipboard.h"
#include "singleapplication.h"
#include "systeminfo.h"
#include "processlauncher.h"
#include "context.h"
#include "viewportslayoutscollectionmodel.h"

void registerQmlTypes()
{
    qmlRegisterSingletonType<Context>("CCTV_Viewer.Core", 1, 0, "Context",
                                      []([[maybe_unused]] QQmlEngine *engine,
                                         [[maybe_unused]] QJSEngine *scriptEngine) -> QObject * {
        return new Context();
    });
    qmlRegisterSingletonType<Clipboard>("CCTV_Viewer.Utils", 1, 0, "Clipboard",
                                                []([[maybe_unused]] QQmlEngine *engine,
                                                   [[maybe_unused]] QJSEngine *scriptEngine) -> QObject * {
                                                    return new Clipboard();
                                                });
    qmlRegisterSingletonType<SingleApplication>("CCTV_Viewer.Utils", 1, 0, "SingleApplication",
                                                []([[maybe_unused]] QQmlEngine *engine,
                                                   [[maybe_unused]] QJSEngine *scriptEngine) -> QObject * {
        return new SingleApplication();
    });
    qmlRegisterSingletonType<SystemInfo>("CCTV_Viewer.Utils", 1, 0, "SystemInfo",
                                         []([[maybe_unused]] QQmlEngine *engine,
                                            [[maybe_unused]] QJSEngine *scriptEngine) -> QObject * {
        return new SystemInfo();
    });
    qmlRegisterSingletonType<ProcessLauncher>("CCTV_Viewer.Utils", 1, 0, "ProcessLauncher",
                                              []([[maybe_unused]] QQmlEngine *engine,
                                                 [[maybe_unused]] QJSEngine *scriptEngine) -> QObject * {
        return new ProcessLauncher();
    });

    qmlRegisterType<QmlAVPlayer>("CCTV_Viewer.Multimedia", 1, 0, "QmlAVPlayer");
    qmlRegisterType<ViewportsLayoutItem>("CCTV_Viewer.Models", 1, 0, "ViewportsLayoutItem");
    qmlRegisterType<ViewportsLayoutModel>("CCTV_Viewer.Models", 1, 0, "ViewportsLayoutModel");
    qmlRegisterType<ViewportsLayoutsCollectionModel>("CCTV_Viewer.Models", 1, 0, "ViewportsLayoutsCollectionModel");

    qmlRegisterType<EventFilter>("CCTV_Viewer.Utils", 1, 0, "EventFilter");
}

int main(int argc, char *argv[])
{
    // Qt6: AA_EnableHighDpiScaling is always enabled, no need to set it

#if defined(APP_NAME)
    QCoreApplication::setApplicationName(QLatin1String(APP_NAME));
#endif
#if defined(APP_VERSION)
    QCoreApplication::setApplicationVersion(QLatin1String(APP_VERSION));
#endif
#if defined(ORG_NAME)
    QCoreApplication::setOrganizationName(QLatin1String(ORG_NAME));
#endif
#if defined(ORG_DOMAIN)
    QCoreApplication::setOrganizationDomain(QLatin1String(ORG_DOMAIN));
#endif

    qInfo() << "CCTV Viewer version:" << APP_VERSION;

    registerQmlTypes();

    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    QTranslator translator;
    const QString locale = QLocale::system().name();
    if (translator.load(QLatin1String("cctv-viewer_") + locale, QLatin1String(":/translations/"))) {
        app.installTranslator(&translator);
    } else {
        qDebug() << "No translation found for locale:" << locale;
    }
    app.setWindowIcon(QIcon(QLatin1String(":/images/cctv-viewer.svg")));

    Context::init();

    engine.addImportPath(":/src/imports");
    const QUrl url(QStringLiteral("qrc:/src/RootWindow.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    // NOTE: Debug
    // Testing Right-to-left User Interfaces...
    // (This code must be removed!!!)
//    QGuiApplication::setLayoutDirection(Qt::RightToLeft);

    return app.exec();
}
