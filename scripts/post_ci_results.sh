# Alpine linux command:
#wget -qO - https://coverage.codacy.com/get.sh | sh -s report -r coverage/coverage.xml

# Bash
# Don't fail the CI if this breaks.
bash <(curl -Ls https://coverage.codacy.com/get.sh) report -r coverage/coverage.xml || true
