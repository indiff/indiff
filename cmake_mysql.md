# Cmake:
```cmake .. -G Ninja \
  # === 基础 ===
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/${TARGET} \
  -DCMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DVCPKG_TARGET_TRIPLET=x64-linux \
  -DCMAKE_CXX_EXTENSIONS=OFF \
  -DBUILD_CONFIG=mysql_release \
  -DINSTALL_LAYOUT=STANDALONE \
  -DMYSQL_SERVER_SUFFIX=-indiff \

  # === 字符集 ===
  -DDEFAULT_CHARSET=utf8mb4 \
  -DDEFAULT_COLLATION=utf8mb4_0900_ai_ci \
  -DWITH_EXTRA_CHARSETS=all \
  -DENABLED_LOCAL_INFILE=1 \

  # === 第三方库 (全部 vcpkg) ===
  -DWITH_SSL=system \
  -DWITH_ZLIB=system \
  -DWITH_ZSTD=system \
  -DWITH_LZ4=system \
  -DWITH_SNAPPY=system \
  -DWITH_ICU=system \
  -DWITH_CURL=system \
  -DWITH_RAPIDJSON=system \
  -DWITH_EDITLINE=bundled \
  -DWITH_PROTOBUF=bundled \
  -DWITH_JEMALLOC=system \

  # === 功能开关 ===
  -DWITH_PERFORMANCE_SCHEMA=ON \
  -DWITH_MYISAM=ON \
  -DWITH_INNOBASE_STORAGE_ENGINE=1 \
  -DWITH_TEMPTABLE_STORAGE_ENGINE=1 \
  -DWITH_CSV_STORAGE_ENGINE=1 \
  -DWITH_ARCHIVE_STORAGE_ENGINE=OFF \
  -DWITH_BLACKHOLE_STORAGE_ENGINE=OFF \
  -DWITH_FEDERATED_STORAGE_ENGINE=OFF \
  -DWITH_EXAMPLE_STORAGE_ENGINE=OFF \
  -DWITH_INNODB_MEMCACHED=OFF \
  -DWITH_ROCKSDB=${ROCKSDB:-OFF} \

  # === 禁用不需要的组件 ===
  -DWITH_ROUTER=OFF \
  -DWITH_NDB=OFF -DWITH_NDBCLUSTER=OFF -DWITH_NDB_JAVA=OFF \
  -DWITH_MYSQLX=0 \
  -DWITH_GROUP_REPLICATION=OFF \
  -DWITH_AUTHENTICATION_LDAP=OFF \
  -DWITH_PAM=OFF \
  -DWITH_FIDO=OFF \
  -DWITH_NUMA=OFF \
  -DWITH_MECAB=OFF \
  -DWITH_EXT_BACKTRACE=OFF \
  -DWITH_EMBEDDED_SERVER=0 \

  # === 测试/文档 ===
  -DWITH_TESTS=0 \
  -DWITH_UNIT_TESTS=OFF \
  -DWITH_BENCHMARK_TOOLS=0 \
  -DWITH_XPLUGIN_TESTS=0 \
  -DWITH_DOCS=OFF \
  -DWITH_MAN_PAGES=OFF \
  -DMYSQL_MAINTAINER_MODE=OFF \
  -DWITH_SAFEMALLOC=OFF \
  -DWITH_DEBUG=0 \

  # === RPATH ===
  '-DCMAKE_INSTALL_RPATH=$ORIGIN/../lib:$ORIGIN/../lib64' \
  '-DCMAKE_BUILD_RPATH=$ORIGIN/../lib:$ORIGIN/../lib64' \
  -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \

  # === 编译标志 ===
  '-DCMAKE_C_FLAGS=-fno-omit-frame-pointer -D__NO_STRING_INLINES -O2 -pipe -fPIC -DPIC' \
  '-DCMAKE_CXX_FLAGS=-std=c++20 -fno-omit-frame-pointer -D__NO_STRING_INLINES -O2 -pipe -fPIC -DPIC' \
  '-DCMAKE_EXE_LINKER_FLAGS=-Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -Wl,-z,now -Wl,-z,relro -ldl -lpthread' \
  '-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -Wl,-z,now -Wl,-z,relro -ldl' \
  '-DCMAKE_MODULE_LINKER_FLAGS=-Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -Wl,-z,now -Wl,-z,relro -ldl'```
