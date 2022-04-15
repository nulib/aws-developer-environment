function asdf-install-npm() {
  tool_files=$(asdf-tool-versions)
  node_versions=$(cat $(echo $tool_files) | grep nodejs | awk '{print $2}' | sort -u)
  npm_versions=$(cat $(echo $tool_files) | grep npm | awk '{print $2}' | sort -u)
  for nodejs in $(echo $node_versions); do 
    for npm in $(echo $npm_versions); do
      echo "Installing npm v${npm} for NodeJS v${nodejs}"
      ASDF_NODEJS_VERSION=${nodejs} npm install -g npm@${npm};
    done
  done  
}

function asdf-install-plugins() {
  tool_files=$(asdf-tool-versions)
  plugins=$(cat $(echo $tool_files) | awk '{print $1}' | grep -v '#' | sort -u)
  for plugin in $(echo $plugins); do
    asdf plugin add $plugin
  done
}

function asdf-tool-versions() {
  result=""
  if [ -e ./.tool-versions ]; then
    result="${result} ${PWD}/.tool-versions"
  fi

  original_dir=$PWD
  while [ $PWD != "/" ]; do
    cd ..
    if [ -e ./.tool-versions ]; then
      result="${result} ${PWD}/.tool-versions"
    fi
  done
  cd $original_dir
  echo $result | xargs
}
