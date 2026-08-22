// Package lexorank 提供基于字典序字符串（Lexicographic Rank）的排序算法，
// 用于看板中看板/列/卡片的稳定排序（Jira/Asana 同款思路）。
//
// 每个可排序实体持有一个字符串 rank；移动实体时取相邻两者 rank 的
// "字典序中点"作为新 rank，使大多数移动只需 O(1) 次写入；仅当键空间
// 局部耗尽（无法在中点约束内产生合法字符串）时，才触发整列重排。
//
// 字符集为 base-36（0-9a-z），rank 为可变长字符串，硬上限 MaxLen。
// 空字符串 "" 作为哨兵：作为下界表示"列首之前"，作为上界表示"列尾之后"。
//
// 本包为纯算法，无第三方依赖、无状态，可独立单测。
package lexorank

import "strings"

const (
	// alphabet 字母表。ASCII 序与索引序一致，因此可直接用原生字符串比较。
	alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

	// base 字母表长度（36）。
	base = len(alphabet)

	// MaxLen rank 字符串的硬上限。中点取值超过该长度视为键空间耗尽，
	// 调用方需对整列执行 Rebalance。36^20 的键空间远超任何现实列基数，
	// 正常中点取值下 rank 长度长期维持在 1~3 个字符。
	MaxLen = 20
)

// maxRank 上界哨兵对应的实际字符串（全 'z'，长度 MaxLen）。
var maxRank = strings.Repeat(alphabet[base-1:], MaxLen)

// idxOf 返回字符在字母表中的索引；非字母表字符返回 -1。
func idxOf(c byte) int {
	switch {
	case c >= '0' && c <= '9':
		return int(c - '0')
	case c >= 'a' && c <= 'z':
		return int(c - 'a' + 10)
	default:
		return -1
	}
}

// validRank 校验 s 是否为合法 rank：仅含字母表字符且不超过 MaxLen。
// 哨兵 "" 合法。
func validRank(s string) bool {
	if len(s) > MaxLen {
		return false
	}
	for i := 0; i < len(s); i++ {
		if idxOf(s[i]) < 0 {
			return false
		}
	}
	return true
}

// Between 返回严格介于 low 与 high 之间的 rank（值空间中点）。
//
//   - low 为 "" 时表示下界哨兵（插到列首之前）；
//   - high 为 "" 时表示上界哨兵（插到列尾之后）；
//   - 二者均为 "" 时返回全键空间的中点（空列首张卡片的位置）。
//
// 若键空间局部耗尽（相邻 rank 无法再插入、或中点长度将超过 MaxLen），
// 返回 ("", false)，调用方应对整列执行 Rebalance 后重试。
func Between(low, high string) (string, bool) {
	if !validRank(low) || !validRank(high) {
		return "", false
	}

	h := high
	if h == "" {
		h = maxRank
	}

	// low 为 "" 是合法下界哨兵；非空时必须严格小于上界。
	if low != "" && low >= h {
		return "", false
	}

	return betweenRec(low, h)
}

// betweenRec 递归求 a、b（a < b，均为具体字符串，b 已映射为 maxRank）
// 之间的值空间中点。三种情形：
//
//  1. a 是 b 的前缀：在 a 末端追加一个小于 b[len(a)] 的中点字符；
//  2. a、b 在位置 i 分叉且间隔 > 1：在 i 处放置 (ca+cb)/2 的中点字符；
//  3. a、b 在位置 i 相邻分叉（cb = ca+1）：位置 i 无法插入，
//     向 a 追加全字母表中点字符（值空间中点恰为 a 的延伸）。
func betweenRec(a, b string) (string, bool) {
	if a >= b {
		return "", false
	}

	n := len(a)
	if len(b) < n {
		n = len(b)
	}
	i := 0
	for i < n && a[i] == b[i] {
		i++
	}

	// 情形 1：a 是 b 的前缀（i == len(a) < len(b)）
	if i == len(a) {
		c := idxOf(b[i])
		if c <= 0 {
			// b 在该位是最小字符，无法放置更小字符，向前递归 consumption b 的前导 '0'
			return betweenRec(a+string(b[i]), b)
		}
		s := a + string(alphabet[(c-1)/2])
		if len(s) > MaxLen {
			return "", false
		}
		return s, true
	}

	// 情形 2/3：在位置 i 分叉（i < len(a) 且 i < len(b)）
	ca, cb := idxOf(a[i]), idxOf(b[i])
	if ca < 0 || cb < 0 || ca >= cb {
		// 防御：非法字符或序异常（正常由 a < b 与 validRank 保证不会发生）
		return "", false
	}

	var s string
	if cb-ca > 1 {
		// 情形 2：间隔内放置中点字符，结果为公共前缀 + 中点字符
		s = a[:i] + string(alphabet[(ca+cb)/2])
	} else {
		// 情形 3：相邻分叉，向 a 追加全字母表中点字符
		s = a + string(alphabet[(base-1)/2])
	}

	if len(s) > MaxLen {
		return "", false
	}
	return s, true
}

// rebalanceMaxLen 重排 rank 的定长上限。36^6 ≈ 2.18e9，配合相邻码距 ≥ 2
// 的约束，可支持单列约 5.4 亿个实体，远超现实基数；超出返回 nil。
const rebalanceMaxLen = 6

// Rebalance 返回 count 个互不相同、升序排列、均匀分布于键空间的新 rank，
// 用于整列重排（键空间局部耗尽时调用）。
//
// 实现为"定长网格均匀铺点"：取定长 L 使 36^L ≥ 4*(count+1)，在整数码空间
// [0, 36^L) 内以 round(i*(36^L-1)/(count+1)) 取 count 个等距码点，再逐位
// 转为 base-36 字符。同长字符串的字典序与码点数值序一致，故结果天然升序；
// 相邻码距 ≥ 3，保证重排后 Between 仍可在任意相邻对之间 O(1) 插入。
//
// count <= 0 返回空切片；count 超出可表示范围（约 5.4 亿）返回 nil，
// 调用方应视为内部错误。
func Rebalance(count int) []string {
	if count <= 0 {
		return []string{}
	}

	// 选定长 L：36^L ≥ 4*(count+1)，上限 rebalanceMaxLen
	mod := 1
	length := 0
	for mod < 4*(count+1) {
		mod *= 36
		length++
		if length > rebalanceMaxLen {
			return nil
		}
	}

	ranks := make([]string, count)
	denom := count + 1
	half := denom / 2
	for i := 1; i <= count; i++ {
		// round(i*(mod-1)/denom)；i、mod 均受 rebalanceMaxLen 约束，不溢出
		code := (i*(mod-1) + half) / denom
		ranks[i-1] = codeToRank(code, length)
	}
	return ranks
}

// codeToRank 将非负整数 code 转为 length 位的 base-36 定长 rank
// （高位在前，零填充）。
func codeToRank(code, length int) string {
	b := make([]byte, length)
	for i := length - 1; i >= 0; i-- {
		b[i] = alphabet[code%base]
		code /= base
	}
	return string(b)
}
