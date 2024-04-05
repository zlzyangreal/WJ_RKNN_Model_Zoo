#!/bin/bash

set -e # 脚本执行过程中遇到错误时立即退出

echo "$0 $@"
while getopts ":t:a:d:b:m" opt; do
  # -t : target (rk356x/rk3588/rk3576/rv1106/rk1808/rv1126)
  # -a : arch (aarch64/armhf)
  # -d : demo name
  # -b : build_type (Debug/Release)
  # -m : enable address sanitizer, build_type need set to Debug
  case $opt in
    t) # -t
      TARGET_SOC=$OPTARG
      ;;
    a) # -a
      TARGET_ARCH=$OPTARG
      ;;
    b) # -b
      BUILD_TYPE=$OPTARG
      ;;
    m) # -m
      # ASAN是AddressSanitizer的缩写，是一种内存错误检测工具，可以检测出内存访问越界、内存泄漏等问题
      ENABLE_ASAN=ON
      export ENABLE_ASAN=TRUE
      ;;
    d) # -d
      BUILD_DEMO_NAME=$OPTARG
      ;;
    :)
      echo "Option -$OPTARG requires an argument." 
      exit 1
      ;;
    ?)
      echo "Invalid option: -$OPTARG index:$OPTIND"
      ;;
  esac
done

if [ -z ${TARGET_SOC} ] || [ -z ${BUILD_DEMO_NAME} ]; then # -z检查
  echo "$0 -t <target> -a <arch> -d <build_demo_name> [-b <build_type>] [-m]"
  echo ""
  echo "    -t : target (rk356x/rk3588/rk3576/rv1106/rk1808/rv1126)"
  echo "    -a : arch (aarch64/armhf)"
  echo "    -d : demo name"
  echo "    -b : build_type(Debug/Release)"
  echo "    -m : enable address sanitizer, build_type need set to Debug"
  echo "such as: $0 -t rk3588 -a aarch64 -d mobilenet"
  echo "Note: 'rk356x' represents rk3562/rk3566/rk3568, 'rv1106' represents rv1103/rv1106, 'rv1126' represents rv1109/rv1126"
  echo ""
  exit -1
fi

# 配置编译器宏 GCC_COMPILER ，rk3588 GCC_COMPILER=aarch64-linux-gnu
if [[ -z ${GCC_COMPILER} ]];then # -z是判断字符串长度是否为0
    if [[ ${TARGET_SOC} = "rv1106"  || ${TARGET_SOC} = "rv1103" ]];then
        echo "Please set GCC_COMPILER for $TARGET_SOC"
        echo "such as export GCC_COMPILER=~/opt/arm-rockchip830-linux-uclibcgnueabihf/bin/arm-rockchip830-linux-uclibcgnueabihf"
        exit
    elif [[ ${TARGET_SOC} = "rv1109" || ${TARGET_SOC} = "rv1126" ]];then
        GCC_COMPILER=arm-linux-gnueabihf
    else
        GCC_COMPILER=aarch64-linux-gnu # aarch64-linux-gnu-gcc
    fi
fi
# 导入环境变量
echo "$GCC_COMPILER"
export CC=${GCC_COMPILER}-gcc
export CXX=${GCC_COMPILER}-g++

# 检查 ${CC} 变量所代表的命令是否可用。如果命令可用，继续执行后续操作；
# 如果命令不可用，打印错误提示信息并退出脚本。
if command -v ${CC} >/dev/null 2>&1; then
    :
else
    echo "${CC} is not available"
    echo "Please set GCC_COMPILER for $TARGET_SOC"
    echo "such as export GCC_COMPILER=~/opt/arm-rockchip830-linux-uclibcgnueabihf/bin/arm-rockchip830-linux-uclibcgnueabihf"
    exit
fi

# Debug / Release
if [[ -z ${BUILD_TYPE} ]];then
    BUILD_TYPE=Release
fi

# 使用地址清理程序构建为了进行内存检查，BUILD_TYPE需要设置为Debug
# Build with Address Sanitizer for memory check, BUILD_TYPE need set to Debug
if [[ -z ${ENABLE_ASAN} ]];then
    ENABLE_ASAN=OFF
fi

# 这段代码的作用是在 examples 目录及其子目录中查找名称为 ${BUILD_DEMO_NAME} 的文件或目录。
# 然后，检查找到的路径中是否存在 cpp 子目录，如果存在，将该路径赋值给 BUILD_DEMO_PATH 变量
for demo_path in `find examples -name ${BUILD_DEMO_NAME}`
do
    if [ -d "$demo_path/cpp" ]
    then
        BUILD_DEMO_PATH="$demo_path/cpp"
        break;
    fi
done

if [[ -z "${BUILD_DEMO_PATH}" ]]
then
    echo "Cannot find demo: ${BUILD_DEMO_NAME}, only support:"

    for demo_path in `find examples -name cpp`
    do
        if [ -d "$demo_path" ]
        then
            dname=`dirname "$demo_path"` # dirname 是一个命令，用于获取指定路径的父目录路径
            name=`basename $dname` # basename 是一个命令，用于获取指定路径的基本文件名
            echo "$name"
        fi
    done
    echo "rv1106_rv1103 only support: mobilenet and yolov5/6/7/8/x"
    exit
fi

case ${TARGET_SOC} in
    rk356x)
        ;;
    rk3588)
        ;;
    rv1106)
        ;;
    rv1103)
        TARGET_SOC="rv1106"
        ;;
    rk3566)
        TARGET_SOC="rk356x"
        ;;
    rk3568)
        TARGET_SOC="rk356x"
        ;;
    rk3562)
        TARGET_SOC="rk356x"
        ;;
    rk3576)
        TARGET_SOC="rk3576"
        ;;
    rk1808):
        TARGET_SOC="rk1808"
        ;;
    rv1109)
        ;;
    rv1126)
        TARGET_SOC="rv1126"
        ;;
    *)
        echo "Invalid target: ${TARGET_SOC}"
        echo "Valid target: rk3562,rk3566,rk3568,rk3588,rk3576,rv1106,rv1103,rk1808,rv1109,rv1126"
        exit -1
        ;;
esac

TARGET_SDK="rknn_${BUILD_DEMO_NAME}_demo"

TARGET_PLATFORM=${TARGET_SOC}_linux
if [[ -n ${TARGET_ARCH} ]];then
TARGET_PLATFORM=${TARGET_PLATFORM}_${TARGET_ARCH}
fi
# ROOT_PWD 
ROOT_PWD=$( cd "$( dirname $0 )" && cd -P "$( dirname "$SOURCE" )" && pwd ) 
# $SOURCE 当前脚本的绝对路径
INSTALL_DIR=${ROOT_PWD}/install/${TARGET_PLATFORM}/${TARGET_SDK}
BUILD_DIR=${ROOT_PWD}/build/build_${TARGET_SDK}_${TARGET_PLATFORM}_${BUILD_TYPE}

echo "==================================="
echo "BUILD_DEMO_NAME=${BUILD_DEMO_NAME}"
echo "BUILD_DEMO_PATH=${BUILD_DEMO_PATH}"
echo "TARGET_SOC=${TARGET_SOC}"
echo "TARGET_ARCH=${TARGET_ARCH}"
echo "BUILD_TYPE=${BUILD_TYPE}"
echo "ENABLE_ASAN=${ENABLE_ASAN}"
echo "INSTALL_DIR=${INSTALL_DIR}"
echo "BUILD_DIR=${BUILD_DIR}"
echo "CC=${CC}"
echo "CXX=${CXX}"
echo "==================================="

if [[ ! -d "${BUILD_DIR}" ]]; then
  mkdir -p ${BUILD_DIR}
fi

if [[ -d "${INSTALL_DIR}" ]]; then
  rm -rf ${INSTALL_DIR}
fi

cd ${BUILD_DIR}
cmake ../../${BUILD_DEMO_PATH} \
    -DTARGET_SOC=${TARGET_SOC} \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=${TARGET_ARCH} \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DENABLE_ASAN=${ENABLE_ASAN} \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}
make -j4
make install

# Check if there is a rknn model in the install directory
suffix=".rknn"
shopt -s nullglob
if [ -d "$INSTALL_DIR" ]; then # -d 检查文件是否存在
    files=("$INSTALL_DIR/model/"/*"$suffix")
    shopt -u nullglob

    if [ ${#files[@]} -le 0 ]; then
        echo -e "\e[91mThe RKNN model can not be found in \"$INSTALL_DIR/model\", please check!\e[0m"
    fi
else
    echo -e "\e[91mInstall directory \"$INSTALL_DIR\" does not exist, please check!\e[0m"
fi
