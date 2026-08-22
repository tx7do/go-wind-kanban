package server

import (
	"errors"
	"strconv"
)

var errInvalidToken = errors.New("invalid token")

// parseBoardID 解析订阅看板 ID（十进制正整数）。
func parseBoardID(raw string) (uint64, error) {
	if raw == "" {
		return 0, errInvalidToken
	}
	return strconv.ParseUint(raw, 10, 32)
}
