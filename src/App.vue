<template>
  <div class="wrapper">
    <form @submit.prevent="addItem" autocomplete="off">
      <h1>Simple to-do list</h1>
      <label> Your tasks: {{ isComplete }} / {{ totalItems }}</label>
    <!-- to add new item into the list -->
      <div class="task">
      <input
        type="text"
        class="task-input"
        v-model="newItem"
        placeholder="Get groceries"
      />
        <!-- Add item on click -->
        <button  class="button btn-add">Add</button>
    </div>
    
    <!-- Show added items in list view-->
    <ul class="task-list">
      <!-- v-for to iterates over the items array and create a list of item for each item in the array -->
      <!-- v-bind to check whether item is completed or not-->
      <li class="task-list-item" 
      v-for="(item, index) in items" :key="index" v-bind:class="{completed: item.completed}">
          <input type="checkbox" 
          v-model="item.completed"/>
          <span>{{ item.text }}</span>
        <!-- delete item on click-->
        <button v-on:click= "deleteItem(index)"
          class="button btn-delete">Remove</button>
      </li>
    </ul>
    </form>
  </div>
</template>

<script>
export default {
  data() {
    return {
      newItem: "", //item before adding into array
      items: [], //store items in array
    };
  },
  computed: {
    totalItems() {
      return this.items.length; //auto increment of 1 of each items added into array
    },
    isComplete() {
      return this.items.filter(item => item.completed).length; //to get completed [checkbox: checked] 
    }
  },
  methods: {
    addItem() {
      if (this.newItem !== "") {
        this.items.push({text: this.newItem, completed: false}); //check if input field is empty, if not empty then push [input] into array [items] and mark not completed [checkbox: unchecked]
        this.newItem = ""; //input becomes empty
      }
    },
    deleteItem(index) {
      this.items.splice(index, 1); //remove item
    }
  },
};
</script>

<style lang="scss">
@import "src/assets/to-do.scss";
</style>