cmake_minimum_required(VERSION 3.10)

project(wj)

if (ENABLE_ASAN)
    # DEBUG 模式 
    # set(CMAKE_BUILD_TYPE "Debug") 
	message(STATUS "BUILD WITH ADDRESS SANITIZER")
	set (CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -fno-omit-frame-pointer -fsanitize=address")
    # -fno-omit-frame-pointer 追踪函数调用堆栈
    # -fsanitize=address AddressSanitizer 工具的选项，用于检测内存错误
	set (CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fno-omit-frame-pointer -fsanitize=address")
	set (CMAKE_LINKER_FLAGS_DEBUG "${CMAKE_LINKER_FLAGS_DEBUG} -fno-omit-frame-pointer -fsanitize=address")
endif ()

# 用不上
if (TARGET_SOC STREQUAL "rv1106" OR TARGET_SOC STREQUAL "rv1103")
    add_definitions(-DRV1106_1103)
    set(rknpu_yolov8_file rknpu2/yolov8_rv1106_1103.cc)
    #dma
    include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../../../3rdparty/allocator/dma)
endif()
# ~~
if(TARGET_SOC STREQUAL "rk1808" OR TARGET_SOC STREQUAL "rv1109" OR TARGET_SOC STREQUAL "rv1126")
    add_definitions(-DRKNPU1)
    set(rknpu_yolov8_file rknpu1/yolov8.cc)
endif()

# 添加存放源文件的子目录
set(rknpu_yolov8_file rknpu2/yolov8.cc)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../../3rdparty/ 3rdparty.out)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../../utils/ utils.out)

set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib") # 安装lib并可执行时找到，很好的宏
# $ORIGIN 表示正在运行的可执行文件的所在目录

# SRCS 变量将包含所有 rknn_model_zoo/examples/yolov8/cpp 目录下以 .cc 结尾的文件的完整路径
file(GLOB SRCS ${CMAKE_CURRENT_SOURCE_DIR}/*.cc) # 匹配

# 生成可执行文件，带上了 rknpu2/yolov8.cc
add_executable(${PROJECT_NAME}
    main.cc
    postprocess.cc
    ${rknpu_yolov8_file}
) # build下

# 链接系列插件库，来自utils，dl是一个系统库，用于在 Linux 系统上进行动态链接，LIBRKNNRT来自第三方库
target_link_libraries(${PROJECT_NAME}
    imageutils
    fileutils
    imagedrawing    
    ${LIBRKNNRT}
    dl
)
# ~~
if (CMAKE_SYSTEM_NAME STREQUAL "Android")
    target_link_libraries(${PROJECT_NAME}
    log
)
endif()

message(STATUS "!!!!!!!!!!!CMAKE_SYSTEM_NAME: ${CMAKE_SYSTEM_NAME}")
# 开线程库
if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # 使用pthreads线程库
    set(THREADS_PREFER_PTHREAD_FLAG ON)
    # 查找系统中可用的线程库，必须项
    find_package(Threads REQUIRED)
    # 添加链接的共享库
    target_link_libraries(${PROJECT_NAME} Threads::Threads)
endif()
# 设置目标的头文件包含路径，私有，LIBRKNNRT_INCLUDES来自第三方库
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LIBRKNNRT_INCLUDES}
)
# 安装到当前目录，使其可在该位置被访问和使用
# 访问权限以及访问路径设置
install(TARGETS ${PROJECT_NAME} DESTINATION .)
# ！！！！！要改！！！！！！！
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../model/bus.jpg DESTINATION model)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../model/coco_80_labels_list.txt DESTINATION model)
# 查找模型位置
file(GLOB RKNN_FILES "${CMAKE_CURRENT_SOURCE_DIR}/../model/*.rknn")
install(FILES ${RKNN_FILES} DESTINATION model)