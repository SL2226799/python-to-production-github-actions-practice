#!/bin/bash

set -e
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


function try-load-dotenv {
    if [ ! -f "$THIS_DIR/.env" ]; then
        echo "no .env file found"
        return 1
    fi

    while read -r line; do
        export "$line"
    done < <(grep -v '^#' "$THIS_DIR/.env" | grep -v '^$')
}

function install:default {
    python -m pip install -r requirements.txt
}

function install {
    python -m pip install --upgrade pip
    python -m pip install --editable "$THIS_DIR/[dev]"
}

function lint {
    pre-commit run --all-files
}

function lint:ci {
    SKIP=no-commit-to-branch pre-commit run --all-files
}

function build {
    python -m build --sdist --wheel "$THIS_DIR"
}

function publish:test {
    try-load-dotenv || true
    twine upload dist/* \
        --repository testpypi \
        --username=__token__ \
        --password="$TEST_PYPI_TOKEN" \
        --verbose
}

function publish:prod {
    try-load-dotenv || true
    twine upload dist/* \
        --repository pypi \
        --username=__token__ \
        --password="$PROD_PYPI_TOKEN" \
        --verbose
}


function clean {
    rm -rf dist build coverage.xml test-reports
    find . \
      -type d \
      \( \
        -name "*cache*" \
        -o -name "*.dist-info" \
        -o -name "*.egg-info" \
        -o -name "*htmlcov" \
      \) \
      -not -path "*env/*" \
      -exec rm -r {} + || true

    find . \
      -type f \
      -name "*.pyc" \
      -not -path "*env/*" \
      -exec rm {} +
}

function release:test {
    clean
    build
    publish:test
}

function release:prod {
    release:test
    publish:prod
}

function test {
    if ["$#" -eq 0]; then
        python -m pytest "$THIS_DIR/tests/" --cov "THIS_DIR/final-python-course-demo"
    else
        python -m pytest "$@"
    fi
}

function test:quick {
    rm -r "$THIS_DIR/test_reports/"
    PYTEST_EXIT_STATUS=0 
    python -m pytest -m "not slow" "$THIS_DIR/tests" \
    --cov "$THIS_DIR/src" \
    --cov-report "html" \
    --cov-report "term" \
    --cov-fail-under 95 || ((PYTEST_EXIT_STATUS+=$?))
    mv htmlcov "$THIS_DIR/test_reports/"
}

function test:wheel-locally {
    deactivate || true
    rm -rf test-env || true
    python -m venv test-env
    source test-env/bin/activate
    clean || true
    pip install build
    build
    pip install ./dist/*.whl pytest pytest-cov
    test:ci
    deactivate || true
}

# execute tests against the installed package; assumes the wheel is already installed
function test:ci {
    INSTALLED_PKG_DIR="$(python -c 'import course_demo; print(course_demo.__path__[0])')"
    # in CI, we must calculate the coverage for the installed package, not the src/ folder
    COVERAGE_DIR="$INSTALLED_PKG_DIR" run-tests
}

function clean {
    rm -rf dist build coverage.xml test-reports
    find . \
      -type d \
      \( \
        -name "*cache*" \
        -o -name "*.dist-info" \
        -o -name "*.egg-info" \
        -o -name "*htmlcov" \
      \) \
      -not -path "*env/*" \
      -exec rm -r {} + || true

    find . \
      -type f \
      -name "*.pyc" \
      -not -path "*env/*" \
      -exec rm {} +
}

function serve-coverage-report {
    python -m http.server --directory "$THIS_DIR/htmlcov/"
}

function help {
    echo "$0 <task> <args>"
    echo "Tasks:"
    compgen -A function | cat -n
}

TIMEFORMAT="Task completed in %3lR"
time ${@:-help}
