#!/bin/bash
get_version() {
  yq -r ".${1}" .github/versions.yaml
}
