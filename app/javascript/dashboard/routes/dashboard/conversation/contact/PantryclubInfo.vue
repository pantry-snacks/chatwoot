<script setup>
import { ref, onMounted } from 'vue';
import PantryclubAPI from 'dashboard/api/pantryclub';

const props = defineProps({
  contactId: { type: Number, required: true },
});

const ADMIN_URL = 'https://sys.pantryclub.co.za';

const customer = ref(null);
const isLoaded = ref(false);

onMounted(async () => {
  try {
    const { data } = await PantryclubAPI.getCustomer(props.contactId);
    customer.value = data.customer;
    isLoaded.value = true;
  } catch {
    // Lookup failures are logged server-side; the row just stays hidden.
  }
});
</script>

<template>
  <div class="contents text-sm text-n-slate-11">
    <template v-if="isLoaded && customer">
      <a
        :href="`${ADMIN_URL}/users/${customer.user_id}`"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center gap-2 hover:underline"
      >
        <span class="i-lucide-user flex-shrink-0 size-3.5" />
        {{ $t('CONTACT_PANEL.PANTRYCLUB.USER_ID', { id: customer.user_id }) }}
      </a>
      <a
        v-if="customer.latest_order_id"
        :href="`${ADMIN_URL}/orders/${customer.latest_order_id}`"
        target="_blank"
        rel="noopener noreferrer"
        class="flex items-center gap-2 hover:underline"
      >
        <span class="i-lucide-shopping-bag flex-shrink-0 size-3.5" />
        {{
          $t('CONTACT_PANEL.PANTRYCLUB.LATEST_ORDER', {
            id: customer.latest_order_id,
            status: customer.latest_order_status.replaceAll('_', ' '),
          })
        }}
      </a>
      <span v-else class="flex items-center gap-2">
        <span class="i-lucide-shopping-bag flex-shrink-0 size-3.5" />
        {{ $t('CONTACT_PANEL.PANTRYCLUB.NO_ORDERS') }}
      </span>
    </template>
    <span v-else-if="isLoaded" class="flex items-center gap-2">
      <span class="i-lucide-user flex-shrink-0 size-3.5" />
      {{ $t('CONTACT_PANEL.PANTRYCLUB.NOT_REGISTERED') }}
    </span>
  </div>
</template>
