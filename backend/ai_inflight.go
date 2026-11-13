package main

import "sync"

// aiInFlight holds user IDs that currently have an AI scan running.
var aiInFlight sync.Map
