<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import MessageApi from 'dashboard/api/inbox/message';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import MessageContent from 'dashboard/modules/search/components/MessageContent.vue';

const MIN_QUERY_LENGTH = 2;
const SEARCH_DEBOUNCE_MS = 300;

const store = useStore();
const { t } = useI18n();
const { run, abort, isPending } = useAbortableRequest();

const isOpen = ref(false);
const query = ref('');
const searchedQuery = ref('');
const results = ref([]);

const currentChat = computed(() => store.getters.getSelectedChat);
const showNoResults = computed(
  () => searchedQuery.value && !isPending.value && !results.value.length
);

const close = () => {
  isOpen.value = false;
  abort();
  query.value = '';
  searchedQuery.value = '';
  results.value = [];
};

const search = debounce(async term => {
  if (term.length < MIN_QUERY_LENGTH) {
    abort();
    searchedQuery.value = '';
    results.value = [];
    return;
  }
  const payload = await run(signal =>
    MessageApi.search(
      { conversationId: currentChat.value.id, query: term },
      { signal }
    )
  );
  // The panel may have been closed while the request was in flight.
  if (!payload || !isOpen.value) return;
  searchedQuery.value = term;
  results.value = useCamelCase(payload.data.payload, { deep: true });
}, SEARCH_DEBOUNCE_MS);

const onInput = value => {
  query.value = value;
  search(value.trim());
};

const authorName = message => message.sender?.name || t('SEARCH.BOT_LABEL');

// ponytail: loads at most 1000 messages between the match and the oldest loaded one; older matches in longer chats leave a gap above them
const jumpToMessage = async messageId => {
  const { id: conversationId, messages } = currentChat.value;
  if (!messages.some(message => message.id === messageId)) {
    await store.dispatch('fetchPreviousMessages', {
      conversationId,
      after: messageId,
      before: messages[0]?.id,
    });
  }
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId });
};
</script>

<template>
  <div v-on-clickaway="close" class="relative flex items-center">
    <ButtonV4
      v-tooltip="$t('CONVERSATION.HEADER.SEARCH_MESSAGES')"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-search"
      @click="isOpen ? close() : (isOpen = true)"
    />
    <div
      v-if="isOpen"
      class="absolute z-50 flex flex-col gap-2 p-3 mt-1 w-96 max-w-[90vw] top-full end-0 rounded-xl border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg"
    >
      <Input
        :model-value="query"
        :placeholder="$t('CONVERSATION.HEADER.SEARCH_MESSAGES_PLACEHOLDER')"
        autofocus
        @update:model-value="onInput"
        @keydown.esc="close"
      />
      <div v-if="isPending" class="flex justify-center py-2">
        <Spinner />
      </div>
      <p
        v-else-if="showNoResults"
        class="py-2 mb-0 text-center text-sm text-n-slate-11"
      >
        {{ $t('CONVERSATION.HEADER.SEARCH_MESSAGES_EMPTY') }}
      </p>
      <ul
        v-else-if="results.length"
        class="flex flex-col gap-1 m-0 overflow-y-auto list-none max-h-96"
      >
        <!-- Not a <button>: MessageContent renders its own read more/less buttons -->
        <li
          v-for="message in results"
          :key="message.id"
          role="button"
          tabindex="0"
          class="flex flex-col gap-1 px-2 py-1.5 rounded-lg cursor-pointer hover:bg-n-alpha-2"
          @click="jumpToMessage(message.id)"
          @keydown.enter="jumpToMessage(message.id)"
        >
          <span class="text-xs text-n-slate-11">
            {{ dynamicTime(message.createdAt) }}
          </span>
          <MessageContent
            :author="authorName(message)"
            :message="message"
            :search-term="searchedQuery"
          />
        </li>
      </ul>
    </div>
  </div>
</template>
