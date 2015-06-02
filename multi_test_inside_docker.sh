#!/bin/bash -e

export ORIGINAL_PATH=$PATH

function test {
  version=$1
  export PATH=$ORIGINAL_PATH

  export GEM_HOME=/tmp/prytmp/$version
  export PATH=/opt/rubies/$version/bin:$GEM_HOME/bin:$PATH
  export RUBY_ROOT=/opt/rubies/$version

  if [ ! -f $GEM_HOME/bin/bundle ]; then
    gem install bundler --no-document
  fi

  bundle install --quiet
  rake test
}

for ruby in `ls /opt/rubies`
do
  test $ruby || :
done
