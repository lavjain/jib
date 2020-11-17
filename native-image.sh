#!/bin/sh

# Do ./gradlew jib-cli:instDist before running this.

set -o errexit

cd jib-cli/build/install/jib

MAIN_CLASS=com.google.cloud.tools.jib.cli.cli2.JibCli bin/jib-native
CLASSPATH=$( find lib/ -name '*.jar' -printf ':%p' | cut -c2- )
echo "* CLASSPATH: ${CLASSPATH}"
echo "* Main class: ${MAIN_CLASS}"

###############################################################################
# Auto-gen Picocli reflection configuration JSON
# (https://picocli.info/picocli-on-graalvm.html)
#
PICOCLI_JAR=../../picocli-4.5.2.jar
PICOCLI_CODEGEN_JAR=../../picocli-codegen-4.5.2.jar
if [ ! -e "${PICOCLI_JAR}" -o ! -e "${PICOCLI_CODEGEN_JAR}" ]; then
  curl -so "${PICOCLI_JAR}" https://repo1.maven.org/maven2/info/picocli/picocli/4.5.2/picocli-4.5.2.jar
  curl -so "${PICOCLI_CODEGEN_JAR}" https://repo1.maven.org/maven2/info/picocli/picocli-codegen/4.5.2/picocli-codegen-4.5.2.jar
fi

echo "* Generating Picocli reflection configuration JSON..."
java -cp "${CLASSPATH}:${PICOCLI_JAR}:${PICOCLI_CODEGEN_JAR}" \
  picocli.codegen.aot.graalvm.ReflectionConfigGenerator \
    "${MAIN_CLASS}" \
    > picocli-reflect.json

###############################################################################
# Generate a native image
#
echo "* Generating a native image..."
native-image --static --no-fallback --no-server \
  -H:ReflectionConfigurationFiles=picocli-reflect.json \
  -H:+ReportUnsupportedElementsAtRuntime \
  -cp "${CLASSPATH}" \
  "${MAIN_CLASS}" bin/jib-native