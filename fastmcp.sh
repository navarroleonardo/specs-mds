py="$HOME/Programas/python-3.14/python.exe"
"$py" -m pip show fastmcp fastmcp-slim | grep -E "^(Name|Version)"
"$py" -m pip install --force-reinstall --no-deps "fastmcp-slim==X.Y.Z"   # X.Y.Z = versão do fastmcp acima
"$py" -c "import fastmcp; print(fastmcp.__version__, fastmcp.__file__)"
