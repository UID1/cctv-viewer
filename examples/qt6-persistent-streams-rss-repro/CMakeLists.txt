cmake_minimum_required(VERSION 3.16)
project(qt6-persistent-streams-rss-repro LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia)

qt_standard_project_setup()

qt_add_executable(rssrepro
    main.cpp
    processrss.cpp
    processrss.h
)

qt_add_resources(rssrepro "qml"
    PREFIX /
    FILES main.qml
)

target_link_libraries(rssrepro PRIVATE Qt6::Quick Qt6::Multimedia)
