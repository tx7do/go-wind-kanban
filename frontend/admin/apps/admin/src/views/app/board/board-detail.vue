<script lang="ts" setup>
import { ref, watch } from 'vue';

import {
  Button,
  Card,
  Empty,
  Input,
  Modal,
  Tag,
  message,
} from 'ant-design-vue';

import { apiClient } from '#/api/client';

interface BoardRow {
  id?: number;
  name?: string;
}

interface ColumnRow {
  id?: number;
  name?: string;
  color?: string;
  rank?: string;
}

interface CardRow {
  id?: number;
  name?: string;
  rank?: string;
  columnId?: number;
}

const props = defineProps<{ board: BoardRow | null }>();

const columns = ref<ColumnRow[]>([]);
const cards = ref<CardRow[]>([]);
const loading = ref(false);

const colModal = ref(false);
const colForm = ref<{ name: string }>({ name: '' });
const cardModal = ref<{ open: boolean; columnId: number }>({ open: false, columnId: 0 });
const cardForm = ref<{ name: string }>({ name: '' });

async function load() {
  const boardId = props.board?.id;
  if (!boardId) return;
  loading.value = true;
  try {
    // admin 面无快照端点；SyncBoard 以空已知版本即返回全量（board + upserted 全集）
    const delta = await apiClient.boardService.SyncBoard({
      boardId,
      knownBoardVersion: 0,
    });
    columns.value = [...(delta.upsertedColumns ?? [])].sort((a, b) =>
      (a.rank ?? '').localeCompare(b.rank ?? ''),
    );
    cards.value = [...(delta.upsertedCards ?? [])].sort((a, b) =>
      (a.rank ?? '').localeCompare(b.rank ?? ''),
    );
  } finally {
    loading.value = false;
  }
}

function cardsOf(columnId?: number): CardRow[] {
  return cards.value.filter((c) => c.columnId === columnId);
}

async function createColumn() {
  if (!colForm.value.name.trim()) return;
  await apiClient.columnService.Create({
    data: { name: colForm.value.name, boardId: props.board?.id },
  });
  message.success('列已创建');
  colModal.value = false;
  colForm.value.name = '';
  await load();
}

async function removeColumn(col: ColumnRow) {
  Modal.confirm({
    title: `删除列「${col.name}」？`,
    content: '列下卡片将级联删除。',
    onOk: async () => {
      await apiClient.columnService.Delete({ id: col.id });
      message.success('已删除');
      await load();
    },
  });
}

async function createCard() {
  if (!cardForm.value.name.trim()) return;
  await apiClient.cardService.Create({
    data: { name: cardForm.value.name, columnId: cardModal.value.columnId },
  });
  message.success('卡片已创建');
  cardModal.value.open = false;
  cardForm.value.name = '';
  await load();
}

async function removeCard(card: CardRow) {
  await apiClient.cardService.Delete({ id: card.id });
  message.success('已删除');
  await load();
}

// 重排：上移一格 = 置于前一项之前（beforeId）；下移一格 = 置于后一项之后（afterId）。
async function moveCard(card: CardRow, dir: -1 | 1) {
  const list = cardsOf(card.columnId);
  const idx = list.findIndex((c) => c.id === card.id);
  if (idx < 0) return;
  const target = idx + dir;
  if (target < 0 || target >= list.length) return;

  const beforeId = dir === -1 ? list[target]?.id : undefined;
  const afterId = dir === 1 ? list[target]?.id : undefined;
  await apiClient.cardService.Move({
    id: card.id,
    beforeId,
    afterId,
  });
  await load();
}

async function moveColumn(col: ColumnRow, dir: -1 | 1) {
  const idx = columns.value.findIndex((c) => c.id === col.id);
  if (idx < 0) return;
  const target = idx + dir;
  if (target < 0 || target >= columns.value.length) return;
  await apiClient.columnService.Move({
    id: col.id,
    beforeId: dir === -1 ? columns.value[target]?.id : undefined,
    afterId: dir === 1 ? columns.value[target]?.id : undefined,
  });
  await load();
}

watch(() => props.board?.id, load, { immediate: true });
</script>

<template>
  <Card size="small" :title="board?.name ?? '看板详情'" class="h-full" :loading="loading">
    <template #extra>
      <Button size="small" @click="colModal = true">新建列</Button>
    </template>

    <Empty v-if="columns.length === 0" description="暂无列，先创建一个列" />
    <div v-else class="flex h-full gap-3 overflow-x-auto pb-2">
      <div
        v-for="col in columns"
        :key="col.id"
        class="w-64 shrink-0 rounded-lg border p-2"
      >
        <div class="mb-2 flex items-center gap-1">
          <Tag v-if="col.color" :color="col.color">{{ col.name }}</Tag>
          <span v-else class="font-medium">{{ col.name }}</span>
          <span class="text-xs opacity-50">{{ cardsOf(col.id).length }}</span>
          <div class="ml-auto flex">
            <Button size="small" type="text" @click="moveColumn(col, -1)">←</Button>
            <Button size="small" type="text" @click="moveColumn(col, 1)">→</Button>
            <Button danger size="small" type="text" @click="removeColumn(col)">
              删
            </Button>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <div
            v-for="card in cardsOf(col.id)"
            :key="card.id"
            class="rounded border px-2 py-1.5 text-sm"
          >
            <div class="flex items-center gap-1">
              <span class="min-w-0 flex-1 truncate">{{ card.name }}</span>
              <Button size="small" type="text" @click="moveCard(card, -1)">↑</Button>
              <Button size="small" type="text" @click="moveCard(card, 1)">↓</Button>
              <Button danger size="small" type="text" @click="removeCard(card)">
                ×
              </Button>
            </div>
          </div>
          <Button block size="small" type="dashed" @click="cardModal = { open: true, columnId: col.id! }">
            + 卡片
          </Button>
        </div>
      </div>
    </div>

    <Modal v-model:open="colModal" title="新建列" @ok="createColumn">
      <Input v-model:value="colForm.name" placeholder="列名称" />
    </Modal>
    <Modal v-model:open="cardModal.open" title="新建卡片" @ok="createCard">
      <Input v-model:value="cardForm.name" placeholder="卡片标题" />
    </Modal>
  </Card>
</template>
