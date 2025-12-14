'use client'

/// Created by Claude
/// UTC: 2025-12-13 19:45
/// California Time (UTC-8): 2025-12-13 11:45

import {
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  useReactTable,
  ColumnDef,
  SortingState,
  ColumnFiltersState,
  ColumnOrderState,
  Header,
  Table,
} from '@tanstack/react-table'
import { useState } from 'react'

interface DataTableProps<TData> {
  columns: ColumnDef<TData, any>[]
  data: TData[]
  onRowClick?: (row: TData) => void
  selectedRowId?: string | null
  getRowId?: (row: TData) => string
  newRowIds?: Set<string>
}

// Resize handle component
function ResizeHandle<TData>({ header }: { header: Header<TData, unknown> }) {
  return (
    <div
      onMouseDown={header.getResizeHandler()}
      onTouchStart={header.getResizeHandler()}
      className={`
        absolute right-0 top-0 h-full w-2 cursor-col-resize select-none touch-none
        bg-slate-600 hover:bg-orange-500 active:bg-orange-400
        ${header.column.getIsResizing() ? 'bg-orange-500' : ''}
      `}
      style={{ userSelect: 'none' }}
    />
  )
}

// Draggable header for column reordering
function DraggableHeader<TData>({
  header,
  table,
}: {
  header: Header<TData, unknown>
  table: Table<TData>
}) {
  const { column } = header
  const [isDragging, setIsDragging] = useState(false)

  const handleDragStart = (e: React.DragEvent) => {
    setIsDragging(true)
    e.dataTransfer.setData('text/plain', column.id)
    e.dataTransfer.effectAllowed = 'move'
  }

  const handleDragEnd = () => {
    setIsDragging(false)
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    const draggedColumnId = e.dataTransfer.getData('text/plain')
    const targetColumnId = column.id

    if (draggedColumnId === targetColumnId) return

    const currentOrder = table.getState().columnOrder
    const columns = table.getAllLeafColumns().map((c) => c.id)
    const order = currentOrder.length ? currentOrder : columns

    const draggedIndex = order.indexOf(draggedColumnId)
    const targetIndex = order.indexOf(targetColumnId)

    const newOrder = [...order]
    newOrder.splice(draggedIndex, 1)
    newOrder.splice(targetIndex, 0, draggedColumnId)

    table.setColumnOrder(newOrder)
  }

  const isSortable = column.getCanSort()

  return (
    <th
      key={header.id}
      draggable
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
      className={`
        px-4 py-3 font-medium text-left text-sm text-slate-400 relative select-none
        ${isDragging ? 'opacity-50' : ''}
        ${isSortable ? 'cursor-pointer hover:text-slate-200' : 'cursor-grab'}
      `}
      style={{ width: header.getSize(), minWidth: 60 }}
      onClick={isSortable ? header.column.getToggleSortingHandler() : undefined}
    >
      <div className="flex items-center gap-1 pr-3">
        {flexRender(column.columnDef.header, header.getContext())}
        {isSortable && (
          <span className="text-xs">
            {{
              asc: ' ↑',
              desc: ' ↓',
            }[column.getIsSorted() as string] ?? ' ↕'}
          </span>
        )}
      </div>
      <ResizeHandle header={header} />
    </th>
  )
}

export default function DataTable<TData>({
  columns,
  data,
  onRowClick,
  selectedRowId,
  getRowId,
  newRowIds = new Set(),
}: DataTableProps<TData>) {
  const [sorting, setSorting] = useState<SortingState>([])
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([])
  const [columnOrder, setColumnOrder] = useState<ColumnOrderState>([])

  const table = useReactTable({
    data,
    columns,
    state: {
      sorting,
      columnFilters,
      columnOrder,
    },
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    onColumnOrderChange: setColumnOrder,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    columnResizeMode: 'onChange',
    enableColumnResizing: true,
    getRowId: getRowId,
  })

  return (
    <div className="bg-slate-800/50 rounded-lg border border-slate-700 overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full" style={{ tableLayout: 'fixed' }}>
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr key={headerGroup.id} className="border-b border-slate-700">
                {headerGroup.headers.map((header) => (
                  <DraggableHeader key={header.id} header={header} table={table} />
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((row) => {
              const rowId = getRowId ? getRowId(row.original) : row.id
              const isSelected = selectedRowId === rowId
              const isNew = newRowIds.has(rowId)

              return (
                <tr
                  key={row.id}
                  onClick={() => onRowClick?.(row.original)}
                  className={`
                    border-b border-slate-700/50 cursor-pointer transition-colors
                    ${isNew ? 'animate-highlight-fade' : ''}
                    ${isSelected
                      ? 'bg-orange-900/20 border-l-2 border-l-orange-500'
                      : 'hover:bg-slate-800/50 border-l-2 border-l-transparent'
                    }
                  `}
                >
                  {row.getVisibleCells().map((cell) => (
                    <td
                      key={cell.id}
                      className="px-4 py-3"
                      style={{ width: cell.column.getSize() }}
                    >
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
