<!-- Attribute type "File" — upload a file, store its URL as the attribute value -->
<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  attribute: {
    type: Object,
    required: true,
  },
  isEditingView: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update', 'delete']);

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const currentUser = useMapGetter('getCurrentUser');

const isUploading = ref(false);
const fileInputRef = ref(null);

const hasValue = computed(() => !!props.attribute.value);

const fileName = computed(() => {
  if (!props.attribute.value) return '';
  try {
    const url = new URL(props.attribute.value);
    const parts = url.pathname.split('/');
    return decodeURIComponent(parts[parts.length - 1]) || 'file';
  } catch {
    return 'file';
  }
});

const triggerFileInput = () => {
  fileInputRef.value?.click();
};

const handleFileChange = async event => {
  const file = event.target.files?.[0];
  if (!file) return;

  isUploading.value = true;
  try {
    const formData = new FormData();
    formData.append('attachment', file);

    const response = await fetch(`/api/v1/accounts/${accountId.value}/upload`, {
      method: 'POST',
      headers: { api_access_token: currentUser.value.access_token },
      body: formData,
    });

    if (!response.ok) throw new Error('Upload failed');

    const data = await response.json();
    emit('update', data.file_url);
  } catch {
    // noop — parent alert handles errors
  } finally {
    isUploading.value = false;
    if (fileInputRef.value) fileInputRef.value.value = '';
  }
};
</script>

<template>
  <div
    class="flex items-center w-full min-w-0 gap-2"
    :class="{
      'justify-start': isEditingView,
      'justify-end': !isEditingView,
    }"
  >
    <!-- Hidden file input -->
    <input
      ref="fileInputRef"
      type="file"
      class="hidden"
      @change="handleFileChange"
    />

    <!-- Display mode: show link + action buttons -->
    <template v-if="!isUploading">
      <a
        v-if="hasValue && isEditingView"
        :href="attribute.value"
        target="_blank"
        rel="noopener noreferrer"
        class="text-sm truncate text-n-blue-11 hover:text-n-brand hover:underline min-w-0"
        :title="attribute.value"
      >
        <span class="i-lucide-paperclip mr-1 inline-block align-middle" />
        {{ fileName }}
      </a>

      <span
        v-else-if="!hasValue"
        class="text-sm cursor-pointer text-n-slate-11 hover:text-n-slate-12 py-2 select-none font-medium"
        :class="{ truncate: isEditingView }"
        @click="!isEditingView ? undefined : triggerFileInput()"
      >
        {{
          isEditingView
            ? t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.TRIGGER.INPUT')
            : t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.TRIGGER.INPUT')
        }}
      </span>

      <span
        v-else-if="hasValue && !isEditingView"
        class="text-sm cursor-pointer text-n-slate-11 hover:text-n-slate-12 py-2 select-none font-medium truncate"
      >
        <span class="i-lucide-paperclip mr-1 inline-block align-middle" />
        {{ fileName }}
      </span>

      <div v-if="isEditingView" class="flex items-center gap-1 flex-shrink-0">
        <Button
          variant="faded"
          color="slate"
          icon="i-lucide-upload"
          size="xs"
          class="flex-shrink-0 opacity-0 group-hover/attribute:opacity-100 hover:no-underline"
          @click="triggerFileInput"
        />
        <Button
          v-if="hasValue"
          variant="faded"
          color="ruby"
          icon="i-lucide-trash"
          size="xs"
          class="flex-shrink-0 opacity-0 group-hover/attribute:opacity-100 hover:no-underline"
          @click="emit('delete')"
        />
      </div>
    </template>

    <!-- Uploading state -->
    <span v-else class="text-sm text-n-slate-11 py-2 flex items-center gap-1">
      <span class="i-lucide-loader-2 animate-spin inline-block" />
      {{ t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.FILE.UPLOADING') }}
    </span>
  </div>
</template>
