// Cree le venv du workspace et installe les dependances avec un cache pip persistant.
// Parametres : extras (defaut 'dev'), cacheDir (defaut volume agent-cache).
def call(Map config = [:]) {
    def extras = config.get('extras', 'dev')
    def cacheDir = config.get('cacheDir', '/home/jenkins/.cache/pip')
    withEnv(["PIP_CACHE_DIR=${cacheDir}"]) {
        sh """
            rm -rf dist reports && mkdir -p reports
            python3 -m venv .venv
            . .venv/bin/activate
            pip install --quiet --upgrade pip
            pip install --quiet -e ".[${extras}]"
        """
    }
}
