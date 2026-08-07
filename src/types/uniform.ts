export interface UniformCategory {
  id: string;
  name: string;
  created_at?: string;
}

export interface UniformItem {
  id: string;
  name: string;
  category: string;
  /** Everything ever added to stock (initial quantity + all restocks). */
  totalQuantity: number;
  /** total - issued. Maintained by the database, never by the client. */
  remainingQuantity: number;
  /** SUM of quantity_taken across this item's issuances. From the database. */
  issuedQuantity: number;
}

export interface IssuedUniform {
  id: string;
  studentName: string;
  uniformId: string;
  uniformName: string;
  uniformCategory: string;
  quantityTaken: number;
  date: string;
  created_at: string;
  sweaterNumber?: string | null;
}
