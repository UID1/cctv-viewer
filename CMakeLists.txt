cmake_minimum_required(VERSION 3.14)

set(VER_MAJ 0)
set(VER_MIN 2)
set(VER_PAT 1)
# set(REL_STATUS "alpha")

set(APP_NAME "CCTV Viewer")
set(ORG_NAME "CCTV Viewer")
set(ORG_DOMAIN "cctv-viewer.org")

set(VERSION "${VER_MAJ}.${VER_MIN}")

if(${VER_PAT} GREATER 0)
    set(VERSION "${VERSION}.${VER_PAT}")
endif()

project(cctv-viewer VERSION ${VERSION} HOMEPAGE_URL "https://github.com/iEvgeny/cctv-viewer" LANGUAGES C CXX)

if(DEFINED REL_STATUS)
    set(VERSION "${VERSION}-${REL_STATUS}")
endif()

### Packager and Git commit
execute_process(COMMAND git -C ${CMAKE_SOURCE_DIR} log --pretty=format:%h -n 1
    OUTPUT_VARIABLE GIT_COMMIT
    ERROR_QUIET
)

if (EXISTS "${CMAKE_SOURCE_DIR}/debian/git-build-recipe.manifest")
    set(PACKAGER "PPA")

    if ("${GIT_COMMIT}" STREQUAL "")
        file(READ "${CMAKE_SOURCE_DIR}/debian/git-build-recipe.manifest" PPA_MANIFEST)
        string(REGEX MATCH "lp:cctv-viewer git-commit:(.......)" _ ${PPA_MANIFEST})
        set(GIT_COMMIT ${CMAKE_MATCH_1})
    endif()
endif()

if(NOT DEFINED PACKAGER)
    if ("${GIT_COMMIT}" STREQUAL "")
        set(PACKAGER "SRC")
    else()
        set(PACKAGER "GIT")
    endif()
endif()

if ("${GIT_COMMIT}" STREQUAL "")
    set(GIT_COMMIT "N/A")
endif()

set(VERSION "${VERSION} ${PACKAGER}.${GIT_COMMIT} (${CMAKE_SYSTEM_PROCESSOR})")
###

add_definitions(-DAPP_NAME="${APP_NAME}" -DAPP_VERSION="${VERSION}" -DORG_NAME="${ORG_NAME}" -DORG_DOMAIN="${ORG_DOMAIN}")

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fix build on LP for Ubuntu 20.04
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")

if(CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT ANDROID)
    add_compile_options(
        -Werror
        -pedantic-errors

        -Wall
        -Wextra
        -Wpedantic

        -Wcast-align
        -Wcast-qual
        # -Wconversion
        -Wctor-dtor-privacy
        -Wduplicated-branches
        -Wduplicated-cond
        -Wextra-semi
        -Wfloat-equal
        -Wlogical-op
        -Wnon-virtual-dtor
        -Wold-style-cast
        # -Woverloaded-virtual
        -Wredundant-decls
        # -Wsign-conversion
        # -Wsign-promo
    )
endif()

# Disable use of C++ API deprecated in Qt 6.0
add_compile_definitions(QT_DISABLE_DEPRECATED_BEFORE=0x060000)

# QtCreator supports the following variables for Android, which are identical to qmake Android variables.
# Check https://doc.qt.io/qt/deployment-android.html for more information.
# They need to be set before the find_package(...) calls below.

#if(ANDROID)
#    set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
#    if (ANDROID_ABI STREQUAL "armeabi-v7a")
#        set(ANDROID_EXTRA_LIBS
#            ${CMAKE_CURRENT_SOURCE_DIR}/path/to/libcrypto.so
#            ${CMAKE_CURRENT_SOURCE_DIR}/path/to/libssl.so)
#    endif()
#endif()

set(QT_LINK_DEPENDENCIES Core Quick Multimedia)

# Qt6 specific dependencies
set(QT6_EXTRA_DEPENDENCIES Core5Compat)

if (ANDROID)
    list(APPEND QT_LINK_DEPENDENCIES Svg)

    set(ANDROID_EXTRA_LIBS
        "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib/libavformat.so"
        "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib/libavcodec.so"
        "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib/libavutil.so"
        "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib/libswscale.so"
        "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib/libswresample.so"
        "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib/libavdevice.so"
        "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib/libavfilter.so"
        )
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(LIBAV REQUIRED
        libavformat
        libavcodec
        libavutil
        libswscale
        libswresample
        libavdevice
    )
    pkg_check_modules(JEMALLOC REQUIRED jemalloc)
    include_directories(${LIBAV_INCLUDE_DIRS})
endif()

# Qt6 migration branch - force Qt6
find_package(QT NAMES Qt6 COMPONENTS ${QT_LINK_DEPENDENCIES} LinguistTools REQUIRED)
if (${QT_VERSION_MAJOR} GREATER 5)
    # Qt6 doesn't have QuickCompiler as a separate component
    # Add Core5Compat for GraphicalEffects compatibility
    find_package(Qt${QT_VERSION_MAJOR} 6.2 COMPONENTS ${QT_LINK_DEPENDENCIES} ${QT6_EXTRA_DEPENDENCIES} LinguistTools REQUIRED)
else()
    message(FATAL_ERROR "Qt6 is required for this branch. Please install Qt6 development packages.")
endif()

file(GLOB TS_FILES "${CMAKE_SOURCE_DIR}/translations/*.ts")

if (${QT_VERSION_MAJOR} GREATER 5)
    # Qt6: use qt_add_resources (QuickCompiler functionality is integrated)
    qt_add_resources(RESOURCES cctv-viewer.qrc)
elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
    qt5_add_resources(RESOURCES cctv-viewer.qrc)
else()
    qtquick_compiler_add_resources(RESOURCES cctv-viewer.qrc)
endif()

set(PROJ_FILES
    src/main.cpp
    src/clipboard.h
    src/singleapplication.h
    src/systeminfo.cpp src/systeminfo.h
    src/processlauncher.cpp src/processlauncher.h
    src/config.cpp src/config.h
    src/context.cpp src/context.h
    src/eventfilter.h src/eventfilter.cpp
    src/viewportslayoutmodel.cpp src/viewportslayoutmodel.h
    src/viewportslayoutscollectionmodel.cpp src/viewportslayoutscollectionmodel.h
    ${RESOURCES}
    ${TS_FILES}
    )

set(QML_IMPORT_PATH "${CMAKE_SOURCE_DIR}/src/imports" CACHE STRING "Additional import path used to resolve QML modules in Qt Creator's code model")

add_subdirectory(src/qmlav)

if (ANDROID)
    add_library(cctv-viewer SHARED ${PROJ_FILES} ${QMLAV_FILES})

    target_include_directories(cctv-viewer PRIVATE "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/include")
    target_link_directories(cctv-viewer PRIVATE "${CMAKE_SOURCE_DIR}/src/qmlav/3rd/FFmpeg/ffbuild/${ANDROID_ABI}/lib")
else()
    add_executable(cctv-viewer ${PROJ_FILES} ${QMLAV_FILES})
endif()

target_include_directories(cctv-viewer PRIVATE ${QMLAV_INCLUDE})

target_compile_definitions(cctv-viewer
    PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)

foreach (ITEM ${QT_LINK_DEPENDENCIES})
    target_link_libraries(cctv-viewer PRIVATE Qt${QT_VERSION_MAJOR}::${ITEM})
endforeach()
# Link Qt6 extra dependencies (Core5Compat for GraphicalEffects)
if (${QT_VERSION_MAJOR} GREATER 5)
    foreach (ITEM ${QT6_EXTRA_DEPENDENCIES})
        target_link_libraries(cctv-viewer PRIVATE Qt${QT_VERSION_MAJOR}::${ITEM})
    endforeach()
endif()
target_link_libraries(cctv-viewer PRIVATE ${QMLAV_LINK_DEPENDENCIES})
if (JEMALLOC_FOUND)
    target_include_directories(cctv-viewer PRIVATE ${JEMALLOC_INCLUDE_DIRS})
    target_compile_definitions(cctv-viewer PRIVATE CCTV_HAVE_JEMALLOC)
    # --no-as-needed keeps libjemalloc on the link line so its malloc interposes
    # glibc for this process, including Qt and FFmpeg.
    target_link_libraries(cctv-viewer PRIVATE
        "-Wl,--push-state,--no-as-needed"
        ${JEMALLOC_LIBRARIES}
        "-Wl,--pop-state")
endif()

set_directory_properties(PROPERTIES CLEAN_NO_CUSTOM true)
set_source_files_properties(${TS_FILES} PROPERTIES OUTPUT_LOCATION "${CMAKE_SOURCE_DIR}/translations")
if (${QT_VERSION_MAJOR} GREATER 5)
    qt_create_translation(QM_FILES ${CMAKE_SOURCE_DIR} ${TS_FILES})
else()
    qt5_create_translation(QM_FILES ${CMAKE_SOURCE_DIR} ${TS_FILES})
endif()

if (UNIX AND NOT ANDROID)
    include(GNUInstallDirs)
    set(CMAKE_INSTALL_PREFIX "/usr")
    install(TARGETS cctv-viewer DESTINATION "${CMAKE_INSTALL_BINDIR}")
    install(FILES "images/cctv-viewer.png" DESTINATION "/usr/share/pixmaps")
    install(FILES "cctv-viewer.desktop" DESTINATION "/usr/share/applications")
    install(PROGRAMS "scripts/cctv-viewer-launch" DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()
