package main

import "strings"

// aiClientMsg returns a video error message that is safe to show to the user.
func aiClientMsg(err error) string {
	m := err.Error()
	for _, p := range []string{"the video must be", "video scan is not set up", "could not read the video", "could not process the video"} {
		if strings.HasPrefix(m, p) {
			return m
		}
	}
	return "could not process the video"
}
