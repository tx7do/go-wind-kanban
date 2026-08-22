package lexorank

import (
	"math/rand"
	"testing"
)

// assertStrictBetween 校验 r 严格介于 low 与 high 之间（考虑 "" 哨兵）。
func assertStrictBetween(t *testing.T, low, high, r string) {
	t.Helper()

	l, h := low, high
	if h == "" {
		h = maxRank
	}
	if l != "" && !(l < r) {
		t.Fatalf("expected low(%q) < r(%q)", low, r)
	}
	if !(r < h) {
		t.Fatalf("expected r(%q) < high(%q)", r, high)
	}
}

func TestBetweenSentinels(t *testing.T) {
	// 空列首张卡片：全键空间中点
	r, ok := Between("", "")
	if !ok || r == "" {
		t.Fatalf("Between(\"\", \"\") = (%q, %v), want non-empty ok", r, ok)
	}
	assertStrictBetween(t, "", "", r)

	// 尾部追加：上界哨兵
	r, ok = Between("h", "")
	if !ok {
		t.Fatalf("Between(\"h\", \"\") failed")
	}
	assertStrictBetween(t, "h", "", r)

	// 列首插入：下界哨兵
	r, ok = Between("", "h")
	if !ok {
		t.Fatalf("Between(\"\", \"h\") failed")
	}
	assertStrictBetween(t, "", "h", r)
}

func TestBetweenAdjacent(t *testing.T) {
	// "0" 与 "1" 相邻：中点应向 "0" 延伸（值空间中点）
	r, ok := Between("0", "1")
	if !ok {
		t.Fatalf("Between(\"0\", \"1\") failed")
	}
	assertStrictBetween(t, "0", "1", r)

	// 最小 rank 之前无法插入：需重排
	if _, ok := Between("", "0"); ok {
		t.Fatalf("Between(\"\", \"0\") should be exhausted (rebalance needed)")
	}

	// 相等输入非法
	if _, ok := Between("a", "a"); ok {
		t.Fatalf("Between equal ranks should fail")
	}
	// 逆序输入非法
	if _, ok := Between("z", "a"); ok {
		t.Fatalf("Between inverted ranks should fail")
	}
	// 非法字符
	if _, ok := Between("A", "z"); ok {
		t.Fatalf("Between invalid alphabet should fail")
	}
}

func TestBetweenMidpoints(t *testing.T) {
	cases := []struct{ low, high string }{
		{"", "zzzzzzzzzzzzzzzzzzzz"},
		{"", "h"},
		{"h", ""},
		{"a", "c"},
		{"a", "b"},
		{"0", "z"},
		{"ab", "az"},
		{"h0", "h1"},
		{"q", "zz"},
	}
	for _, c := range cases {
		r, ok := Between(c.low, c.high)
		if !ok {
			t.Fatalf("Between(%q, %q) unexpected failure", c.low, c.high)
		}
		if len(r) > MaxLen {
			t.Fatalf("Between(%q, %q) result %q exceeds MaxLen", c.low, c.high, r)
		}
		assertStrictBetween(t, c.low, c.high, r)
	}
}

func TestRebalance(t *testing.T) {
	if got := Rebalance(0); len(got) != 0 {
		t.Fatalf("Rebalance(0) = %v, want empty", got)
	}
	if got := Rebalance(-3); len(got) != 0 {
		t.Fatalf("Rebalance(-3) = %v, want empty", got)
	}

	for _, n := range []int{1, 2, 3, 10, 100, 1000, 10000} {
		ranks := Rebalance(n)
		if ranks == nil {
			t.Fatalf("Rebalance(%d) = nil, want %d ranks", n, n)
		}
		if len(ranks) != n {
			t.Fatalf("Rebalance(%d) returned %d ranks", n, len(ranks))
		}

		seen := make(map[string]struct{}, n)
		for i, r := range ranks {
			if !validRank(r) || r == "" {
				t.Fatalf("Rebalance(%d)[%d] = %q invalid", n, i, r)
			}
			if _, dup := seen[r]; dup {
				t.Fatalf("Rebalance(%d)[%d] = %q duplicated", n, i, r)
			}
			seen[r] = struct{}{}

			if i > 0 && !(ranks[i-1] < r) {
				t.Fatalf("Rebalance(%d) not strictly ascending at %d: %q >= %q",
					n, i, ranks[i-1], r)
			}
		}

		// 重排后相邻间隙应仍可插入，保证后续 O(1) 插入
		for i := 1; i < n; i++ {
			if _, ok := Between(ranks[i-1], ranks[i]); !ok {
				t.Fatalf("Rebalance(%d): gap between %q and %q exhausted",
					n, ranks[i-1], ranks[i])
			}
		}
	}
}

func TestRebalanceDeterministic(t *testing.T) {
	a := Rebalance(50)
	b := Rebalance(50)
	if len(a) != len(b) {
		t.Fatalf("Rebalance not deterministic: len %d vs %d", len(a), len(b))
	}
	for i := range a {
		if a[i] != b[i] {
			t.Fatalf("Rebalance not deterministic at %d: %q vs %q", i, a[i], b[i])
		}
	}
}

// TestFrontInsertionTriggersRebalance 模拟持续向列首插入：
// 头部字符不断折半，最终触底（无法再小于 '0'）返回耗尽信号，
// 此时 Rebalance 应能恢复整列。
func TestFrontInsertionTriggersRebalance(t *testing.T) {
	column := []string{}
	exhausted := false

	for i := 0; i < 200 && !exhausted; i++ {
		low := ""
		high := ""
		if len(column) > 0 {
			high = column[0]
		}
		r, ok := Between(low, high)
		if !ok {
			exhausted = true
			break
		}
		column = append([]string{r}, column...)
	}

	if !exhausted {
		t.Fatalf("expected front insertion to eventually exhaust without rebalance")
	}

	ranks := Rebalance(len(column) + 1)
	if ranks == nil {
		t.Fatalf("Rebalance after exhaustion failed")
	}
	column = ranks

	if len(column) != len(ranks) {
		t.Fatalf("column size mismatch after rebalance")
	}
	for i := 1; i < len(column); i++ {
		if !(column[i-1] < column[i]) {
			t.Fatalf("column not ascending after rebalance at %d", i)
		}
	}
}

// TestColumnSimulation 随机模拟列的插入/移动：每次在随机位置插入，
// Between 耗尽时整列 Rebalance；全程校验升序、互异、长度约束不变量。
func TestColumnSimulation(t *testing.T) {
	rng := rand.New(rand.NewSource(42))
	column := []string{}
	rebalances := 0

	for op := 0; op < 20000; op++ {
		idx := rng.Intn(len(column) + 1)

		var low, high string
		if idx > 0 {
			low = column[idx-1]
		}
		if idx < len(column) {
			high = column[idx]
		}

		r, ok := Between(low, high)
		if ok {
			column = append(column, "")
			copy(column[idx+1:], column[idx:])
			column[idx] = r
		} else {
			rebalances++
			size := len(column) + 1
			column = Rebalance(size)
			if column == nil {
				t.Fatalf("rebalance failed at op %d (size %d)", op, size)
			}
		}

		// 不变量：严格升序、互异、合法、长度受限
		for i := 1; i < len(column); i++ {
			if !(column[i-1] < column[i]) {
				t.Fatalf("op %d: invariant broken at %d: %q >= %q", op, i, column[i-1], column[i])
			}
		}
	}

	if rebalances == 0 {
		t.Logf("simulation finished with %d items, no rebalance triggered", len(column))
	} else {
		t.Logf("simulation finished with %d items, %d rebalances", len(column), rebalances)
	}
}
