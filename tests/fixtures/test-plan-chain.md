# Chain Dependencies Test Plan

**Goal:** Test grouping when each task depends on the previous one

---

### Task 1: Create base

**Files:**
- Create: `src/base.ts`

---

### Task 2: Extend base

**Files:**
- Modify: `src/base.ts`
- Create: `src/level1.ts`

---

### Task 3: Extend level1

**Files:**
- Modify: `src/level1.ts`
- Create: `src/level2.ts`

---

### Task 4: Extend level2

**Files:**
- Modify: `src/level2.ts`
- Create: `src/level3.ts`

---

### Task 5: Final integration

**Files:**
- Modify: `src/level3.ts`
- Create: `src/final.ts`
