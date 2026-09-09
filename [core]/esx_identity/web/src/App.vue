<!--
  SPDX-License-Identifier: GPL-3.0-only
  Copyright (C) 2022-2026 ESX Framework
-->

<script setup>
import { onMounted } from 'vue';
import Identity from './components/Identity.vue'

onMounted(() => {
  fetch("http://esx_identity/ready", {
    method: "POST",
    body: JSON.stringify({}),
  });

  window.addEventListener("message", (event) => {
    if (event.data.type === "enableui") {
        document.body.classList[event.data.enable ? "remove" : "add"]("none");
    }
  });
})

</script>

<template>
  <Identity/>
</template>

<style scoped>

</style>
