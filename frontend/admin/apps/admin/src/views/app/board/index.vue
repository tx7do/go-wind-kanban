<script lang="ts" setup>
import { reactive, ref } from 'vue';

import { ColPage } from '@vben/common-ui';

import BoardDetail from './board-detail.vue';
import BoardList from './board-list.vue';

const props = reactive({
  leftCollapsedWidth: 0,
  leftCollapsible: false,
  leftMaxWidth: 40,
  leftMinWidth: 26,
  leftWidth: 30,
  rightWidth: 70,
  resizable: true,
  splitHandle: true,
  splitLine: true,
});

const selectedBoard = ref<{ id?: number; name?: string } | null>(null);
</script>

<template>
  <ColPage auto-content-height v-bind="props">
    <template #left>
      <BoardList @select="(b) => (selectedBoard = b)" />
    </template>
    <BoardDetail :board="selectedBoard" />
  </ColPage>
</template>
