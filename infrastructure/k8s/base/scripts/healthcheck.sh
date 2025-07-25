#!/bin/sh
curl -fsS --max-time 5 http://localhost:5000/health || exit 1
