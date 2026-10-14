#define lcompat_c
#define LUA_LIB

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

#define LEVELS1 12
#define LEVELS2 10

static int findfield (lua_State *L, int objidx, int level) {
  if (level == 0 || !lua_istable(L, -1))
    return 0;
  lua_pushnil(L);
  while (lua_next(L, -2)) {
    if (lua_type(L, -2) == LUA_TSTRING) {
      if (lua_rawequal(L, objidx, -1)) {
        lua_pop(L, 1);
        return 1;
      }
      else if (findfield(L, objidx, level - 1)) {
        lua_remove(L, -2);
        lua_pushliteral(L, ".");
        lua_insert(L, -2);
        lua_concat(L, 3);
        return 1;
      }
    }
    lua_pop(L, 1);
  }
  return 0;
}

static int pushglobalfuncname (lua_State *L, lua_Debug *ar) {
  int top = lua_gettop(L);
  lua_getinfo(L, "f", ar);
  lua_pushvalue(L, LUA_GLOBALSINDEX);
  if (findfield(L, top + 1, 2)) {
    lua_replace(L, top + 1);
    lua_pop(L, 1);
    return 1;
  }
  else {
    lua_settop(L, top);
    return 0;
  }
}

static void pushfuncname (lua_State *L, lua_Debug *ar) {
  if (*ar->namewhat != '\0')
    lua_pushfstring(L, "function '%s'", ar->name);
  else if (*ar->what == 'm')
    lua_pushliteral(L, "main chunk");
  else if (*ar->what == 'C') {
    if (pushglobalfuncname(L, ar)) {
      lua_pushfstring(L, "function '%s'", lua_tostring(L, -1));
      lua_remove(L, -2);
    }
    else
      lua_pushliteral(L, "?");
  }
  else
    lua_pushfstring(L, "function <%s:%d>", ar->short_src, ar->linedefined);
}

static int countlevels (lua_State *L) {
  lua_Debug ar;
  int li = 1, le = 1;
  while (lua_getstack(L, le, &ar)) { li = le; le *= 2; }
  while (li < le) {
    int m = (li + le) / 2;
    if (lua_getstack(L, m, &ar)) li = m + 1;
    else le = m;
  }
  return le - 1;
}

LUALIB_API void luaL_traceback (lua_State *L, lua_State *L1, const char *msg, int level) {
  lua_Debug ar;
  int top = lua_gettop(L);
  int numlevels = countlevels(L1);
  int mark = (numlevels > LEVELS1 + LEVELS2) ? LEVELS1 : 0;
  if (msg) lua_pushfstring(L, "%s\n", msg);
  lua_pushliteral(L, "stack traceback:");
  while (lua_getstack(L1, level++, &ar)) {
    if (level == mark) {
      lua_pushliteral(L, "\n\t...");
      level = numlevels - LEVELS2;
    }
    else {
      lua_getinfo(L1, "Slnt", &ar);
      lua_pushfstring(L, "\n\t%s:", ar.short_src);
      if (ar.currentline > 0)
        lua_pushfstring(L, "%d:", ar.currentline);
      lua_pushliteral(L, " in ");
      pushfuncname(L, &ar);
      lua_concat(L, lua_gettop(L) - top);
    }
  }
  lua_concat(L, lua_gettop(L) - top);
}

static uint32_t bit_check (lua_State *L, int idx) {
  double n = luaL_checknumber(L, idx);
  return (uint32_t)(int64_t)n;
}

static int bit_result (lua_State *L, uint32_t value) {
  lua_pushnumber(L, (lua_Number)(int32_t)value);
  return 1;
}

static int bit_tobit (lua_State *L) { return bit_result(L, bit_check(L, 1)); }
static int bit_bnot (lua_State *L) { return bit_result(L, ~bit_check(L, 1)); }

static int bit_band (lua_State *L) {
  int i, n = lua_gettop(L);
  uint32_t value = bit_check(L, 1);
  for (i = 2; i <= n; i++) value &= bit_check(L, i);
  return bit_result(L, value);
}

static int bit_bor (lua_State *L) {
  int i, n = lua_gettop(L);
  uint32_t value = bit_check(L, 1);
  for (i = 2; i <= n; i++) value |= bit_check(L, i);
  return bit_result(L, value);
}

static int bit_bxor (lua_State *L) {
  int i, n = lua_gettop(L);
  uint32_t value = bit_check(L, 1);
  for (i = 2; i <= n; i++) value ^= bit_check(L, i);
  return bit_result(L, value);
}

static int bit_lshift (lua_State *L) { return bit_result(L, bit_check(L, 1) << (bit_check(L, 2) & 31)); }
static int bit_rshift (lua_State *L) { return bit_result(L, bit_check(L, 1) >> (bit_check(L, 2) & 31)); }
static int bit_arshift (lua_State *L) { return bit_result(L, (uint32_t)((int32_t)bit_check(L, 1) >> (bit_check(L, 2) & 31))); }

static int bit_rol (lua_State *L) {
  uint32_t value = bit_check(L, 1), n = bit_check(L, 2) & 31;
  return bit_result(L, (value << n) | (value >> ((32 - n) & 31)));
}

static int bit_ror (lua_State *L) {
  uint32_t value = bit_check(L, 1), n = bit_check(L, 2) & 31;
  return bit_result(L, (value >> n) | (value << ((32 - n) & 31)));
}

static int bit_bswap (lua_State *L) {
  uint32_t v = bit_check(L, 1);
  return bit_result(L, (v >> 24) | ((v >> 8) & 0xff00) | ((v & 0xff00) << 8) | (v << 24));
}

static int bit_tohex (lua_State *L) {
  uint32_t value = bit_check(L, 1);
  int n = lua_isnone(L, 2) ? 8 : (int)luaL_checknumber(L, 2);
  const char *digits = "0123456789abcdef";
  char buffer[8];
  int i;
  if (n < 0) { n = -n; digits = "0123456789ABCDEF"; }
  if (n > 8) n = 8;
  for (i = n - 1; i >= 0; i--) { buffer[i] = digits[value & 15]; value >>= 4; }
  lua_pushlstring(L, buffer, (size_t)n);
  return 1;
}

static const luaL_Reg bit_funcs[] = {
  {"tobit", bit_tobit},
  {"bnot", bit_bnot},
  {"band", bit_band},
  {"bor", bit_bor},
  {"bxor", bit_bxor},
  {"lshift", bit_lshift},
  {"rshift", bit_rshift},
  {"arshift", bit_arshift},
  {"rol", bit_rol},
  {"ror", bit_ror},
  {"bswap", bit_bswap},
  {"tohex", bit_tohex},
  {NULL, NULL}
};

LUALIB_API int luaopen_bit (lua_State *L) {
  luaL_register(L, "bit", bit_funcs);
  return 1;
}
