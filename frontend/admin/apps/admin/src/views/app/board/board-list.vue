<script lang="ts" setup>
import { onMounted, ref } from 'vue';

import { Button, Card, Input, List, ListItem, Modal, message } from 'ant-design-vue';

import { apiClient } from '#/api/client';

interface BoardRow {
  id?: number;
  name?: string;
  description?: string;
  rank?: string;
  version?: number;
}

const emit = defineEmits<{ select: [board: BoardRow] }>();

const boards = ref<BoardRow[]>([]);
const loading = ref(false);
const selectedId = ref<number>(0);
const modalOpen = ref(false);
const createForm = ref<{ name: string; description: string }>({
  name: '',
  description: '',
});

async function load() {
  loading.value = true;
  try {
    const resp = await apiClient.boardService.List({ noPaging: true });
    boards.value = [...(resp.items ?? [])].sort((a, b) =>
      (a.rank ?? '').localeCompare(b.rank ?? ''),
    );
    if (!selectedId.value && boards.value[0]) {
      select(boards.value[0]!);
    }
  } finally {
    loading.value = false;
  }
}

function select(b: BoardRow) {
  selectedId.value = b.id ?? 0;
  emit('select', b);
}

async function createBoard() {
  if (!createForm.value.name.trim()) return;
  await apiClient.boardService.Create({
    data: { name: createForm.value.name, description: createForm.value.description },
  });
  message.success('看板已创建');
  modalOpen.value = false;
  createForm.value = { name: '', description: '' };
  await load();
}

async function removeBoard(b: BoardRow) {
  Modal.confirm({
    title: `删除看板「${b.name}」？`,
    content: '列与卡片将级联删除，操作不可恢复。',
    onOk: async () => {
      await apiClient.boardService.Delete({ id: b.id });
      message.success('已删除');
      if (selectedId.value === b.id) selectedId.value = 0;
      await load();
    },
  });
}

onMounted(load);
defineExpose({ refresh: load });
</script>

<template>
  <Card size="small" title="看板" class="h-full">
    <template #extra>
      <Button size="small" type="primary" @click="modalOpen = true">新建</Button>
    </template>
    <List :data-source="boards" :loading="loading" size="small">
      <template #renderItem="{ item }">
        <ListItem
          :class="{ 'board-selected': item.id === selectedId }"
          style="cursor: pointer; padding: 6px 8px"
          @click="select(item)"
        >
          <div class="flex w-full items-center gap-2">
            <div class="min-w-0 flex-1">
              <div class="truncate font-medium">{{ item.name }}</div>
              <div class="truncate text-xs opacity-60">
                {{ item.description || `rank=${item.rank}` }}
              </div>
            </div>
            <Button danger size="small" type="text" @click.stop="removeBoard(item)">
              删除
            </Button>
          </div>
        </ListItem>
      </template>
    </List>

    <Modal v-model:open="modalOpen" title="新建看板" @ok="createBoard">
      <div class="flex flex-col gap-3 py-2">
        <Input v-model:value="createForm.name" placeholder="看板名称" />
        <Input v-model:value="createForm.description" placeholder="描述（可选）" />
      </div>
    </Modal>
  </Card>
</template>

<style scoped>
.board-selected {
  background: hsl(var(--primary) / 8%);
  border-radius: 6px;
}
</style>
