// Calcule la version <majeur>.<mineur>.<BUILD_NUMBER> a partir de pyproject.toml,
// l'ecrit dans pyproject.toml et la renvoie (aussi exposee dans env.VERSION).
def call() {
    def base = sh(returnStdout: true, script: '''python3 -c "import tomllib; \
print(tomllib.load(open('pyproject.toml', 'rb'))['project']['version'])"''').trim()
    def parties = base.tokenize('.')
    def version = "${parties[0]}.${parties[1]}.${env.BUILD_NUMBER}"
    sh "sed -i 's/^version = .*/version = \"${version}\"/' pyproject.toml"
    env.VERSION = version
    currentBuild.displayName = "#${env.BUILD_NUMBER} - ${version}"
    return version
}
