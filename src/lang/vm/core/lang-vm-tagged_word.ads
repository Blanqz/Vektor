with Interfaces;
use Interfaces;

package Lang.VM.Tagged_Word is

   type Tag is mod 2 ** 3;
   for Tag'Size use 3;

   Tag_Heap  : constant Tag := 0;  --  000
   Tag_Int   : constant Tag := 1;  --  001
   Tag_Imm   : constant Tag := 2;  --  010
   Tag_Box   : constant Tag := 3;  --  011

   type Tagged_Word is private;

   function Make_Heap_Ptr (Addr : Interfaces.Unsigned_64) return Tagged_Word
     with Inline, Pre => (Addr mod 8 = 0), Post => Tag_Of (Make_Heap_Ptr'Result) = Tag_Heap;

   function Make_Small_Int (Value : Interfaces.Integer_64) return Tagged_Word
     with Inline, Pre  => Value >= -2 ** 60 and then Value <= 2 ** 60 - 1,
          Post => Tag_Of (Make_Small_Int'Result) = Tag_Int;

   function Make_Box_Ptr (Addr : Interfaces.Unsigned_64) return Tagged_Word
     with Inline, Pre => (Addr mod 8 = 0), Post => Tag_Of (Make_Box_Ptr'Result) = Tag_Box;

   function Make_Bool (Value : Boolean) return Tagged_Word
     with Inline;
   function Make_None return Tagged_Word
     with Inline;
   function Make_Unit return Tagged_Word
     with Inline;
   function Make_Char (Value : Wide_Wide_Character) return Tagged_Word
     with Inline;
   function Make_Pid (Value : Interfaces.Unsigned_64) return Tagged_Word
     with Inline;

   function Tag_Of (Word : Tagged_Word) return Tag
     with Inline, Post => Tag_Of'Result = Tag (To_Raw (Word) and 16#7#);

   function Is_Heap_Pointer (Word : Tagged_Word) return Boolean
     with Inline;
   function Is_Small_Int (Word : Tagged_Word) return Boolean
     with Inline;
   function Is_Immediate (Word : Tagged_Word) return Boolean
     with Inline;
   function Is_Box (Word : Tagged_Word) return Boolean
     with Inline;

   function To_Raw (Word : Tagged_Word) return Interfaces.Unsigned_64
     with Inline;

   function Unbox_Small_Int (Word : Tagged_Word) return Interfaces.Integer_64
     with Inline, Pre => Is_Small_Int (Word);

   function Unbox_Heap_Ptr (Word : Tagged_Word) return Interfaces.Unsigned_64
     with Inline, Pre => Is_Heap_Pointer (Word);

   function Unbox_Box_Ptr (Word : Tagged_Word) return Interfaces.Unsigned_64
     with Inline, Pre => Is_Box (Word);

   function Unbox_Bool (Word : Tagged_Word) return Boolean
     with Inline, Pre => Is_Immediate (Word);

   function Unbox_Pid (Word : Tagged_Word) return Interfaces.Unsigned_64
     with Inline, Pre => Is_Immediate (Word);

   None_Value : constant Tagged_Word;
   Unit_Value : constant Tagged_Word;

private

   type Tagged_Word is new Interfaces.Unsigned_64;
   for Tagged_Word'Size use 64;

   None_Value : constant Tagged_Word := Tagged_Word (16#8000000000000002#);
   Unit_Value : constant Tagged_Word := Tagged_Word (16#800000000000000A#);
end Lang.VM.Tagged_Word;