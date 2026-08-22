import type { RouteRecordRaw } from 'vue-router';

import { BasicLayout } from '#/layouts';
import { $t } from '#/locales';

const board: RouteRecordRaw[] = [
  {
    path: '/board',
    name: 'BoardManagement',
    component: BasicLayout,
    redirect: '/board/boards',
    meta: {
      order: 1500,
      icon: 'lucide:kanban-square',
      title: $t('menu.board.management'),
      authority: ['sys:platform_admin', 'sys:tenant_manager'],
    },
    children: [
      {
        path: 'boards',
        name: 'BoardKanbanManagement',
        meta: {
          order: 1,
          icon: 'lucide:kanban-square',
          title: $t('menu.board.management'),
          authority: ['sys:platform_admin', 'sys:tenant_manager'],
        },
        component: () => import('#/views/app/board/index.vue'),
      },
    ],
  },
];

export default board;
