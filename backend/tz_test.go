package main

import (
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestReqTZ(t *testing.T) {
	gin.SetMode(gin.TestMode)
	cases := map[string]string{
		"Asia/Kolkata": "Asia/Kolkata",
		"":             "",
		"Not/AZone":    "",
		"Local":        "",
		"UTC":          "UTC",
	}
	for in, want := range cases {
		c, _ := gin.CreateTestContext(httptest.NewRecorder())
		c.Request = httptest.NewRequest("GET", "/", nil)
		if in != "" {
			c.Request.Header.Set("X-Timezone", in)
		}
		if got := reqTZ(c); got != want {
			t.Fatalf("reqTZ(%q) = %q, want %q", in, got, want)
		}
	}
}
