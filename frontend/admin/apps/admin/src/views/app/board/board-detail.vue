<script lang="ts" setup>
import { ref, watch } from 'vue';

import {
  Button,
  Card,
  Collapse,
  CollapsePanel,
  Empty,
  Input,
  Modal,
  Select,
  SelectOption,
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

interface LabelRow {
  id?: number;
  name?: string;
  color?: string;
  boardId?: number;
  version?: number;
}

const props = defineProps<{ board: BoardRow | null }>();

const columns = ref<ColumnRow[]>([]);
const cards = ref<CardRow[]>([]);
const labels = ref<LabelRow[]>([]);
const loading = ref(false);

const colModal = ref(false);
const colForm = ref<{ name: string }>({ name: '' });
const cardModal = ref<{ open: boolean; columnId: number }>({ open: false, columnId: 0 });
const cardForm = ref<{ name: string }>({ name: '' });
const labelModal = ref(false);
const labelForm = ref<{ id?: number; name: string; color: string; version?: number }>({
  name: '',
  color: 'gray',
});

const PRESET_COLORS = [
  'gray',
  'red',
  'orange',
  'amber',
  'yellow',
  'lime',
  'green',
  'emerald',
  'teal',
  'cyan',
  'sky',
  'blue',
  'indigo',
  'violet',
  'purple',
  'fuchsia',
  'pink',
  'rose',
];

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
  loadLabels();
}

async function loadLabels() {
  const boardId = props.board?.id;
  if (!boardId) {
    labels.value = [];
    return;
  }
  try {
    const resp = await apiClient.labelService.List({ noPaging: true });
    labels.value = (resp.items ?? []).filter((l) => l.boardId === boardId);
  } catch {
    labels.value = [];
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
  if (target < 0 || target >= columns.length) return;
  await apiClient.columnService.Move({
    id: col.id,
    beforeId: dir === -1 ? columns.value[target]?.id : undefined,
    afterId: dir === 1 ? columns.value[target]?.id : undefined,
  });
  await load();
}

function openCreateLabel() {
  labelForm.value = { name: '', color: 'gray' };
  labelModal.value = true;
}

function openEditLabel(label: LabelRow) {
  labelForm.value = {
    id: label.id,
    name: label.name ?? '',
    color: label.color ?? 'gray',
    version: label.version,
  };
  labelModal.value = true;
}

async function saveLabel() {
  if (!labelForm.value.name.trim() || !props.board?.id) return;
  try {
    if (labelForm.value.id) {
      await apiClient.labelService.Update({
        id: labelForm.value.id,
        data: {
          name: labelForm.value.name,
          color: labelForm.value.color,
          boardId: props.board.id,
        },
        expectedVersion: labelForm.value.version,
        updateMask: 'name,color',
      });
      message.success('标签已更新');
    } else {
      await apiClient.labelService.Create({
        data: {
          name: labelForm.value.name,
          color: labelForm.value.color,
          boardId: props.board.id,
        },
      });
      message.success('标签已创建');
    }
  } catch (e) {
    message.error(`操作失败: ${e}`);
  }
  labelModal.value = false;
  await loadLabels();
}

async function removeLabel(label: LabelRow) {
  Modal.confirm({
    title: `删除标签「${label.name}」？`,
    content: '将移除所有卡片上的该标签关联。',
    onOk: async () => {
      await apiClient.labelService.Delete({ id: label.id });
      message.success('已删除');
      await loadLabels();
    },
  });
}

watch(() => props.board?.id, load, { immediate: true });
</script>


<template>
  <Card size="small" :title="board?.name ?? '看板详情'" class="h-full" :loading="loading">
    <template #extra>
      <Button size="small" @click="colModal = true">新建列</Button>
    </template>

    <Collapse :bordered="false" class="mb-3">
      <CollapsePanel key="labels" header="标签管理">
        <div class="mb-2 flex items-center justify-between">
          <span class="text-xs opacity-50">看板级标签定义（{{ labels.length }}）</span>
          <Button size="small" @click="openCreateLabel">新建标签</Button>
        </div>
        <Empty v-if="labels.length === 0" description="暂无标签" />
        <div v-else class="flex flex-wrap gap-2">
          <div
            v-for="label in labels"
            :key="label.id"
            class="flex items-center gap-1 rounded border px-2 py-1"
          >
            <Tag :color="label.color">{{ label.name }}</Tag>
            <Button size="small" type="text" @click="openEditLabel(label)">编辑</Button>
            <Button danger size="small" type="text" @click="removeLabel(label)">删除</Button>
          </div>
        </div>
      </CollapsePanel>
    </Collapse>

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
    <Modal
      v-model:open="labelModal"
      :title="labelForm.id ? '编辑标签' : '新建标签'"
      @ok="saveLabel"
    >
      <div class="flex flex-col gap-3">
        <Input v-model:value="labelForm.name" placeholder="标签名称" />
        <div class="flex flex-col gap-1">
          <span class="text-xs opacity-50">颜色</span>
          <Select v-model:value="labelForm.color">
            <SelectOption v-for="c in PRESET_COLORS" :key="c" :value="c">{{ c }}</SelectOption>
          </Select>
        </div>
      </div>
    </Modal>
  </Card>
</template>
