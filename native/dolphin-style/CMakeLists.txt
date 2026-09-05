cmake_minimum_required(VERSION 3.20)
project(nothingos_dolphin_style LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.7 REQUIRED COMPONENTS Widgets)
find_package(KF6KIO 6.21 REQUIRED)

add_library(nothingos-dolphin-style MODULE style.cpp)
set_target_properties(nothingos-dolphin-style PROPERTIES PREFIX "")
target_link_libraries(nothingos-dolphin-style PRIVATE Qt6::Widgets KF6::KIOFileWidgets)

include(CTest)
if(BUILD_TESTING)
    add_executable(test-dolphin-style ../../tests/test-dolphin-style.cpp)
    target_link_libraries(test-dolphin-style PRIVATE Qt6::Widgets KF6::KIOFileWidgets)
    add_test(NAME dolphin-style-rendering COMMAND test-dolphin-style $<TARGET_FILE:nothingos-dolphin-style>)
    set_tests_properties(dolphin-style-rendering PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endif()
